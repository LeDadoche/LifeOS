import WidgetKit
import SwiftUI

// MARK: - Tasks Widget

struct TasksEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]
}

struct TaskItem: Codable, Identifiable {
    let id: Int
    let title: String
    let isStarred: Bool
    let hasReminder: Bool
    let dueDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isStarred = "is_starred"
        case hasReminder = "has_reminder"
        case dueDate = "due_date"
    }
}

struct TasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(date: Date(), tasks: [
            TaskItem(id: 1, title: "Exemple de tâche", isStarred: true, hasReminder: false, dueDate: nil)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> ()) {
        let entry = TasksEntry(date: Date(), tasks: loadTasks())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> ()) {
        let tasks = loadTasks()
        let entry = TasksEntry(date: Date(), tasks: tasks)
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadTasks() -> [TaskItem] {
        guard let userDefaults = UserDefaults(suiteName: "group.com.lifeos.widget"),
              let jsonString = userDefaults.string(forKey: "tasks_data"),
              let data = jsonString.data(using: .utf8) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([TaskItem].self, from: data)
        } catch {
            print("Error decoding tasks: \(error)")
            return []
        }
    }
}

struct TasksWidgetEntryView: View {
    var entry: TasksProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Tâches")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 4)
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            if entry.tasks.isEmpty {
                Spacer()
                Text("Aucune tâche")
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(5)) { task in
                    TaskRowView(task: task)
                }
                Spacer()
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1E3A5F"), Color(hex: "2C5282")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct TaskRowView: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Radio button
            Image(systemName: "circle")
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(formatDate(dueDate))
                            .font(.caption2)
                    }
                    .foregroundColor(isOverdue(dueDate) ? .red : .white.opacity(0.6))
                }
            }
            
            Spacer()
            
            if task.hasReminder {
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Image(systemName: task.isStarred ? "star.fill" : "star")
                .font(.system(size: 14))
                .foregroundColor(task.isStarred ? .yellow : .white.opacity(0.4))
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "fr_FR")
        outputFormatter.dateFormat = "EEE d MMM"
        return outputFormatter.string(from: date)
    }
    
    private func isOverdue(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return false }
        return date < Date()
    }
}

struct TasksWidget: Widget {
    let kind: String = "TasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tâches LifeOS")
        .description("Affiche vos tâches en cours")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
