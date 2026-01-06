# LifeOS

A secure, modular, local-first Life Companion application.

## Architecture

This project follows a Feature-First architecture with Clean Architecture principles.

### Structure

- `lib/core`: Shared components, utilities, and services (The OS).
- `lib/features`: Modular features (The Apps).

### Tech Stack

- **Frontend**: Flutter
- **State Management**: Riverpod (with Code Generation)
- **Navigation**: GoRouter
- **Database**: Isar
- **UI**: flutter_staggered_grid_view

## Getting Started

1.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

2.  **Run Code Generation** (Required for Riverpod):
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
    Or watch for changes:
    ```bash
    dart run build_runner watch --delete-conflicting-outputs
    ```

3.  **Run the App**:
    ```bash
    flutter run
    ```
