import WidgetKit
import SwiftUI

// MARK: - Agenda Widget

struct AgendaEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]
}

struct EventItem: Codable, Identifiable {
    let id: Int
    let title: String
    let date: String
    let isAllDay: Bool
    let location: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case isAllDay = "is_all_day"
        case location
    }
}

struct AgendaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgendaEntry {
        AgendaEntry(date: Date(), events: [
            EventItem(id: 1, title: "Exemple d'événement", date: ISO8601DateFormatter().string(from: Date()), isAllDay: false, location: nil)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> ()) {
        let entry = AgendaEntry(date: Date(), events: loadEvents())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgendaEntry>) -> ()) {
        let events = loadEvents()
        let entry = AgendaEntry(date: Date(), events: events)
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadEvents() -> [EventItem] {
        guard let userDefaults = UserDefaults(suiteName: "group.com.lifeos.widget"),
              let jsonString = userDefaults.string(forKey: "events_data"),
              let data = jsonString.data(using: .utf8) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([EventItem].self, from: data)
        } catch {
            print("Error decoding events: \(error)")
            return []
        }
    }
}

struct AgendaWidgetEntryView: View {
    var entry: AgendaProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.white)
                Text("Agenda")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 4)
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            if entry.events.isEmpty {
                Spacer()
                Text("Aucun événement à venir")
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.events.prefix(3)) { event in
                    EventRowView(event: event)
                }
                Spacer()
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "2E7D32"), Color(hex: "388E3C")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct EventRowView: View {
    let event: EventItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.8))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(formatTime(event.date, isAllDay: event.isAllDay))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let location = event.location, !location.isEmpty {
                        Text("• \(location)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            if !isToday(event.date) {
                VStack(spacing: 0) {
                    Text(dayOfMonth(event.date))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(monthAbbr(event.date))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(6)
            }
        }
    }
    
    private func formatTime(_ dateString: String, isAllDay: Bool) -> String {
        if isAllDay {
            return "Toute la journée"
        }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "HH:mm"
        return outputFormatter.string(from: date)
    }
    
    private func isToday(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return false }
        return Calendar.current.isDateInToday(date)
    }
    
    private func dayOfMonth(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d"
        return outputFormatter.string(from: date)
    }
    
    private func monthAbbr(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "fr_FR")
        outputFormatter.dateFormat = "MMM"
        return outputFormatter.string(from: date).uppercased()
    }
}

struct AgendaWidget: Widget {
    let kind: String = "AgendaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AgendaProvider()) { entry in
            AgendaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Agenda LifeOS")
        .description("Affiche vos 3 prochains rendez-vous")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
