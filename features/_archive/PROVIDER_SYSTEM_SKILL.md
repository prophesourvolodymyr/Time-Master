# Skill: global-provider-architecture

## Description
Guide the implementation of a centralized, decoupled state management architecture using the Global Provider/Store pattern. This pattern isolates business logic, persistence, and external side-effects away from the UI, resulting in a highly maintainable, scalable, and testable codebase across any frontend framework (React, SwiftUI, Vue, Flutter, etc.).

## When to Use
Use this skill when initializing a new application, refactoring messy local state, or when the user asks to set up "stores", "providers", or "global state management". 

## Core Principles
1. **Single Source of Truth:** Each major domain of the app (e.g., `AuthStore`, `DataStore`, `SettingsStore`) has exactly one centralized state manager.
2. **Separation of Concerns:** 
   - **Views** are "dumb" — they only handle rendering and local transient UI state (like dropdown toggles or form inputs).
   - **Stores/Providers** hold the business logic, state mutations, and coordination.
   - **Services/Managers** handle pure side-effects (API calls, File System, Audio, Bluetooth) and are called *by* the Stores, never directly by the Views.
3. **Dependency Injection:** Stores are instantiated once near the root of the application and injected down the tree (via Context, Environment Objects, or Provide/Inject) to avoid prop-drilling.

## Architecture Components

### 1. Models (Entities)
Pure data structures, interfaces, or types. No logic.
- **Rule:** Must be easily serializable/deserializable (e.g., JSON).

### 2. Services / Managers (Side-effects)
Stateless singletons or pure functions that wrap external APIs, databases, or device hardware.
- **Examples:** `NetworkManager`, `StorageService`, `AudioPlayer`.
- **Rule:** Never hold UI state. Only return data or throw errors.

### 3. Stores / Providers (State & Logic)
The core of the architecture. Classes or reactive objects that hold the domain state.
- **Responsibilities:**
  - Initialize default state or load from `StorageService`.
  - Expose explicitly defined action methods (`addX`, `deleteY`, `updateZ`).
  - Handle persistence synchronization (e.g., saving to local storage whenever state changes).
- **Rule:** Views must call the action methods on the Store to mutate data. Views should never mutate global state directly.

### 4. The Root Provider (Injection)
The application entry point where Stores are instantiated and provided to the UI tree.

### 5. Views (Consumers)
UI components that read state from the injected Stores and dispatch actions.
- **Rule:** Always access the Store via the framework's native context/environment hook.

## Framework Mappings

When applying this pattern, use the framework's idiomatic tools:

**SwiftUI (iOS/macOS):**
- *Store:* `class MyStore: ObservableObject` with `@Published` properties.
- *Root Injection:* `.environmentObject(MyStore())`
- *View Consumption:* `@EnvironmentObject var store: MyStore`

**React (Web/Native):**
- *Store:* React Context + Custom Hook (`useReducer` or `useState`), OR a Zustand/Redux store.
- *Root Injection:* `<MyStoreContext.Provider value={store}>`
- *View Consumption:* `const store = useMyStore()`

**Vue:**
- *Store:* Pinia Store (`defineStore`).
- *Root Injection:* `app.use(pinia)`
- *View Consumption:* `const store = useMyStore()`

**Flutter:**
- *Store:* `ChangeNotifier` or Riverpod `Notifier`.
- *Root Injection:* `ChangeNotifierProvider(create: (_) => MyStore())`
- *View Consumption:* `context.watch<MyStore>()`

## Implementation Steps for AI
1. **Analyze Domain:** Identify the core data domains required by the app (e.g., `User`, `Items`).
2. **Generate Models:** Define the pure data structures.
3. **Generate Services:** Create wrappers for persistence (Local Storage/UserDefaults) or APIs.
4. **Generate Stores:** Build the reactive state managers. Implement `init()` to load saved data, and `save()` functions called internally upon mutations.
5. **Setup Root:** Wrap the main app entry point with the necessary Providers.
6. **Build Views:** Create UI components that consume the Store and call its methods. Do NOT put business logic in the view's callbacks.