# Mqtee

Multi-platform MQTT client for macOS 26+, iOS 26+, and iPadOS 26+. SwiftUI UI over a Rust MQTT core via UniFFI. Single universal Xcode target.

## README and repo files

Root public files: `README.md` (logo, sections, footer), `LICENSE.md` (Apache-2.0 + brand notice), `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CONTRIBUTING.md`. Copyright: Felipe Lima. Branding is not Apache-covered. Do not invent product version labels in docs (write present-tense facts). Do not put personal contact data, business plans, or ASC review identity in this tree.

## Requirements

- **macOS**: 26.0+ (Tahoe) - No backwards compatibility
- **iOS/iPadOS**: 26.0+
- **Xcode**: 26.0+
- **Swift**: 6.0+
- **Rust**: 1.85.0+ (edition 2024)
- **cargo-bundle-licenses**: For generating open source license attribution

## Latest Versions Policy

This project targets the latest versions of SwiftUI, Swift, and Rust. Always use the newest stable APIs and language features available. Do not constrain to older patterns when newer alternatives exist.

- **SwiftUI**: Use the latest SwiftUI APIs (macOS 26 / iOS 26). Prefer new view modifiers, containers, and patterns over legacy approaches.
- **Swift**: Use Swift 6.0+ features including strict concurrency, modern async/await patterns, and latest language additions.
- **Rust**: Use edition 2024 features and latest stable Rust idioms.

## Context7 Usage

Always use Context7 (`resolve-library-id` + `query-docs`) to look up documentation and code examples before writing or modifying code. This applies to:

- Any SwiftUI API usage (views, modifiers, layout, navigation, animations)
- Swift language features and standard library APIs
- Rust crate APIs (rumqttc, tokio, uniffi, rustls, serde, thiserror, tracing)
- Any third-party library or framework used in this project

Do not rely on memorized or potentially outdated knowledge. Query Context7 first to ensure you are using the correct, up-to-date API signatures and patterns.

## Design System

This app uses **Liquid Glass** design guidelines:
- Use `NavigationSplitView` for sidebar layouts
- Use `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` for buttons
- Use `.listStyle(.sidebar)` for lists
- Avoid custom backgrounds on navigation elements
- Use standard toolbar APIs
- Sheet dialogs: header with title, divider, content, divider, footer with Cancel (left) and action button (right)

## Architecture

- **UI Layer**: SwiftUI (multi-platform) with Liquid Glass
- **MQTT Core**: Rust library exposed via UniFFI bindings (supports MQTT 3.1.1 and 5.0 via dual-protocol client)
- **Pattern**: Swift handles UI and user interactions, Rust handles all MQTT protocol operations
- **MQTT v5 Architecture**: Rust `ClientInner` enum with `V311`/`V5` variants branching on `MqttVersion` config. Uses `rumqttc` for v3.1.1 and `rumqttc::v5` for MQTT 5.0. Swift `MQTTService` bridges both protocols through a unified delegate interface.
- **Storage**:
  - UserDefaults / iCloud (NSUbiquitousKeyValueStore) for connection metadata
  - Keychain (iCloud-synced) for credentials (passwords, certificates)
  - Application Support (`~/Library/Application Support/mqtee/sessions/`) for session persistence

## Project Structure

```
mqtee/
  mqtee/                     # SwiftUI application code
    mqteeApp.swift           # App entry point, menus, keyboard shortcuts, settings
    ContentView.swift        # Root view (wraps ConnectionManagerView)
    Localizable.xcstrings    # String Catalog for localization (auto-populated by Xcode)
    mqtee.entitlements       # Keychain access group entitlements
    Assets.xcassets/         # App icons use Xcode 26 Icon Composer (.icon format)
    Resources/
      licenses.json          # Generated open source license bundle (from cargo-bundle-licenses)
    Models/
      Connection.swift       # MQTT broker connection config, MQTTVersion, QoSLevel, LastWillSettings
      ConnectionStore.swift  # @Observable store with iCloud sync for connections and folders
      SessionStore.swift     # Active session state: subscriptions, messages, topic tree, publish tabs
      TopicTree.swift        # Hierarchical topic organization with TopicNode
      MQTTMessage.swift      # Message model, Subscription with MQTT 5 options, SubscriptionColor
      LogEntry.swift         # Structured event log entry with level, category, direction
      LogStore.swift         # Global singleton log store (max 1,000 entries)
      PublishTab.swift       # Publish tab state and persistence
      PayloadContentType.swift # Auto-detect JSON, XML, plainText, binary payloads
      FocusedValues.swift    # SwiftUI focused values for menu actions
      LicenseEntry.swift     # License data model + LicenseBundle loader for bundled licenses.json
    Intents/
      ConnectionEntity.swift       # App Entity for MQTT connections (Shortcuts)
      ConnectionEntityQuery.swift  # Entity query for finding connections
      MQTeeShortcutsProvider.swift # App Shortcuts provider (Siri integration)
      IntentMQTTClient.swift       # Lightweight MQTT client for intent execution
      PublishMessageIntent.swift   # App Intent: publish an MQTT message
      GetRetainedValueIntent.swift # App Intent: get a retained value from a topic
    Design/
      BrandTheme.swift             # Brand colors, gradients, animation curves
      AnimationModifiers.swift     # View modifiers for staggered entrance animations
    Views/
      ConnectionManagerView.swift  # Main view: sidebar connections + detail (NavigationSplitView)
      ConnectionSidebarView.swift  # Sidebar with connection list, folders, drag & drop
      ConnectionDetailView.swift   # Connection detail pane (session or editor)
      WelcomeView.swift            # Welcome/onboarding view when no connection selected
      SessionView.swift            # Active MQTT session: tree, publish popover, log panel
      PublishPanelContent.swift    # Multi-tab publish panel with QoS, retain, format options
      TreeView.swift               # Topic tree browser + subscription list tabs
      TopicNodeRow.swift           # Topic node and subscription root node row views
      MessageDetailView.swift      # Full message detail view with payload display
      MessageRowView.swift         # Compact message row for topic tree lists
      PayloadDisplayView.swift     # Async payload rendering (JSON, XML, hex, text)
      ConnectionEditorView.swift   # Connection config sheet (TLS, auth, LWT)
      LogView.swift                # Event log panel with filtering
      ConnectionRowView.swift      # Sidebar row for a connection
      ConnectionStatusPopover.swift # Connection status details (macOS popover)
      ConnectionStatusSheet.swift  # Connection status details (iOS sheet)
      AppLogoView.swift            # Animated welcome logo
      CodeEditor.swift             # Syntax-highlighted code editor for payloads
      SettingsViews.swift          # Settings UI: GeneralSettingsView + iOS SettingsSheet wrapper
      LicensesSettingsView.swift   # Open source license list + detail views
      ExportSheet.swift            # Message export dialog
      ImportSheet.swift            # Connection import dialog
    Services/
      MQTTService.swift            # Swift wrapper around Rust MqttClient, event dispatching
      KeychainService.swift        # Keychain CRUD for ConnectionCredentials (iCloud-synced)
      SessionPersistenceService.swift # Batched JSON persistence to Application Support
      FaviconService.swift         # Favicon loading for broker hosts
      JSONHighlighter.swift        # JSON syntax highlighting
      SyntaxTheme.swift            # Color themes for code editor
      PlatformImage.swift          # Cross-platform image type (NSImage/UIImage)
      MessageExportService.swift    # Message export to file (JSON, CSV)
      PlatformClipboard.swift      # Cross-platform clipboard abstraction
      mqtee_core.swift             # Generated UniFFI Swift bindings (do not edit)
  rust/                      # Rust MQTT core library
    Cargo.toml               # Package config and dependencies
    build.rs                 # UniFFI build script (proc-macro mode)
    uniffi-bindgen.rs        # UniFFI binding generator binary
    build-xcframework.sh     # Universal binary build script (arm64 + x86_64)
    src/
      lib.rs                 # Library entry, logging init
      client.rs              # MqttClient: dual-protocol (v3.1.1/v5) async event loop, command pattern, TLS
      types.rs               # Type definitions and conversions (MqttMessage, ConnectionEvent, v5 properties)
      error.rs               # MqttError enum with thiserror
  mqteeTests/                # Swift unit tests (Swift Testing framework)
    Models/                  # Model unit tests
    Services/                # Service unit tests
  mqteeUITests/              # UI tests (XCTest framework)
  mqteeIntegrationTests/     # Integration tests (local rumqttd broker)
  MQTeeCore/                 # Built Rust library output (generated, not committed; just build-rust)
    mqtee_core.xcframework/  # XCFramework with macOS + iOS slices
    Headers/mqtee_coreFFI.h  # FFI C header
    Headers/module.modulemap # Module map for Swift import
    Sources/mqtee_core.swift # Generated Swift bindings (copied to Services/)
  justfile                   # Build task runner
```

## Key Models

- **Connection**: MQTT broker connection configuration (host, port, TLS, auth, LWT, persistence settings)
- **ConnectionStore**: `@Observable` store with iCloud sync for connections and folders
- **SessionStore**: Active session state (subscriptions, messages, topic tree, publish tabs, auto-resubscribe)
- **Subscription**: MQTT subscription with MQTT 5 options (noLocal, retainAsPublished, retainHandling)
- **TopicTree**: Hierarchical topic organization with cache-based node lookup and auto-eviction
- **LogStore**: Global singleton event log (max 1,000 entries, categorized by level/category/direction)
- **PublishTab**: Multi-tab publish state with per-connection persistence
- **LicenseEntry**: Rust dependency license data decoded from `licenses.json` (generated by `cargo-bundle-licenses`)

## Rust Core

### Dependencies
- `rumqttc` 0.25 - MQTT 3.1.1 and 5.0 client with rustls TLS (v5 via `rumqttc::v5` module)
- `tokio` 1 - Async runtime (rt-multi-thread, sync, time, macros)
- `uniffi` 0.28 - Swift FFI generation (proc-macro mode, no UDL)
- `rustls` 0.23 - TLS implementation
- `rustls-pemfile` 2 - PEM certificate parsing
- `webpki-roots` 0.26 - Root CA certificates
- `thiserror` 2 - Error handling
- `tracing` / `tracing-subscriber` - Logging

### Architecture
- Dual-protocol client: `ClientInner` enum with `V311`/`V5` variants, each wrapping separate `rumqttc` client+eventloop
- Command pattern via `tokio::sync::mpsc` channel for thread-safe operations
- `biased` select in event loop: commands first, events second
- Custom `InsecureCertVerifier` for insecure TLS mode
- Events delivered to Swift via `MqttEventHandler` callback interface
- MQTT v5 features: session expiry, subscription options (noLocal, retainAsPublished, retainHandling), publish properties (contentType, responseTopic, correlationData, messageExpiryInterval, payloadFormatIndicator), ConnAck server capabilities

## Multi-Platform

- **Single target**: One app target supports macOS, iOS, and iPadOS (no separate targets)
- **Platform conditionals**: Use `#if os(macOS)` / `#else` for platform-specific code
- **macOS-only APIs**: `VSplitView`, `HSplitView`, `onContinuousHover`, `onExitCommand`, `.commands {}`, `Settings {}`, `openWindow`, `onKeyPress`
- **Layout adaptation**: macOS uses split views; iPad uses `NavigationSplitView`; iPhone collapses to stack navigation
- **Image handling**: Use `PlatformImage` type alias and `Image(platformImage:)` instead of `NSImage`/`Image(nsImage:)`
- **Clipboard**: Use `PlatformClipboard.copy()` instead of `NSPasteboard` directly
- **Sheet sizing**: Wrap fixed `.frame(width:height:)` on sheets in `#if os(macOS)` (iOS sizes sheets naturally)
- **FocusedValues**: macOS menu commands use `@FocusedValue` bindings; wrap these in `#if os(macOS)`
- **XCFramework**: Rust library is built as an XCFramework containing macOS + iOS slices

## Swift Conventions

- SwiftUI for all UI components
- Use `@State private var` for local state, `@Observable` for shared state
- Use `@Bindable` when passing observable objects to child views
- Prefer Swift async/await over Combine
- 4-space indentation
- PascalCase for types, camelCase for properties/methods
- Make models `Codable` when persistence is needed
- Views must render their full layout immediately without "No X Selected" placeholder states.

## File Size Guidelines

- **Soft max**: ~150 lines per file
- **Hard limit**: 300 lines -- files exceeding this must be split
- Generated files are exempt (`mqtee_core.swift`, `mqtee_coreFFI.h`)
- **Swift**: use `Type+Feature.swift` extension files; keep type definition and stored properties in the main file, move method groups to extensions by responsibility
- **Rust**: convert `file.rs` to `file/mod.rs` with submodules when splitting
- When splitting Swift extensions: change `private` to `internal` for properties accessed from extension files
- Each file should have a single, clear responsibility

## Localization (i18n)

- **String Catalog**: `mqtee/Localizable.xcstrings` -- Xcode auto-extracts strings on build
- **Development language**: English (`en`)
- SwiftUI string literals in `Text()`, `Button()`, `Label()`, `Toggle()`, `Picker()`, `Section()`, `.navigationTitle()`, `.help()`, `TextField()` placeholder are auto-localized (treated as `LocalizedStringKey`)
- For strings that bypass auto-localization (computed properties returning `String`, `.rawValue` used as display text), use `String(localized:comment:)`
- Enums with `.rawValue` used as display text must have a `localizedName` computed property using `String(localized:)` -- use `.localizedName` in views, not `.rawValue`
- **MQTT-specific terms are never translated**: protocol versions (MQTT 3.1.1, MQTT 5.0), QoS levels, retain handling options, subscription options, payload formats (JSON, XML, Hex), log levels (DEBUG, INFO, WARN, ERROR), log categories (Connection, Subscription, Publish, Keep Alive), and MQTT error descriptions. These use plain `String` or `rawValue`, not `String(localized:)`.
- Log/diagnostic messages (in `SessionStore`, `MQTTService` protocol events) are developer-facing and stay in English
- Pluralization: never use manual ternaries (`count == 1 ? "" : "s"`); use plain interpolated strings and configure plural variants in the String Catalog editor
- Adding a new language requires no code changes -- add the language in Xcode's String Catalog editor and translate

## Rust Conventions

- Edition 2024, minimum version 1.85.0
- Run clippy with `-D warnings`
- rustfmt with `max_width = 120` and `tab_spaces = 2`
- Use UniFFI for Swift bindings
- Use `tokio` for async runtime with `biased` select for predictable event handling
- Release profile: `lto = true`, `codegen-units = 1`, `opt-level = "z"`, `strip = true`

## UniFFI Integration

- Rust library exposes MQTT functionality through UniFFI (pure proc-macro mode, no UDL file)
- All FFI types use `#[derive(uniffi::Record)]`, `#[derive(uniffi::Enum)]`, `#[uniffi::export]` proc macros
- Generated Swift bindings in `mqtee/Services/mqtee_core.swift`
- Built library in `MQTeeCore/mqtee_core.xcframework/` (macOS + iOS XCFramework)
- Handle async Rust calls with `Task.detached` in Swift

## Building

### Using just (recommended)

```sh
just build-rust    # Build Rust XCFramework (macOS + iOS) and generate Swift bindings
just clean-rust    # Clean Rust build artifacts and MQTeeCore/
just check-rust    # cargo check
just test-rust     # cargo test
just fmt-rust      # cargo fmt
just lint-rust     # cargo clippy -D warnings
just generate-licenses  # Generate open source license bundle from Rust deps
just rebuild       # Full clean + build
just build-ios     # Build for iOS device
just build-ios-sim # Build for iOS Simulator
```

### Manual

1. Build Rust XCFramework: `cd rust && ./build-xcframework.sh`
2. Open `mqtee.xcodeproj` and build in Xcode (select macOS or iOS destination)
3. Regenerate UniFFI bindings after Rust API changes

## Distribution

- **App Store**: macOS + iOS/iPadOS. Free download; no in-app purchases or feature locks.
- **App Store compliance**: Follow App Store Review Guidelines. Keep the in-app Legal links (Privacy Policy, EULA) in `GeneralSettingsView` (guideline 5.1.1 requires a privacy policy link inside the app).

## Testing

### Test Targets

| Target | Framework | Purpose |
|--------|-----------|---------|
| `mqteeTests` | Swift Testing | Unit tests (models, services, no network) |
| `mqteeUITests` | XCTest | UI layout validation tests |
| `mqteeIntegrationTests` | Swift Testing | Integration tests against local rumqttd broker |

### Running Tests

```sh
just test-rust           # Rust unit tests
just test-swift          # Swift unit tests on macOS (mqteeTests)
just test-swift-ios      # Swift unit tests on iOS Simulator
just test-ui             # UI tests on macOS (mqteeUITests)
just test-ui-ios         # UI tests on iOS Simulator
just test-integration    # Integration tests (requires network)
just test-all            # Rust + Swift macOS unit tests
```

### Conventions

- Swift unit tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`)
- UI tests use **XCTest** (`XCUIApplication`, `XCTAssert*`) -- required for UI automation
- Integration tests are guarded by `INTEGRATION_TESTS` compilation condition
- Always set `TZ=UTC` for test environments
- Use `@Suite("Name", .serialized)` for tests with shared state (e.g., LogStore)
- Test files mirror source structure: `mqteeTests/Models/`, `mqteeTests/Services/`
- **Never run UI tests (`mqteeUITests`) unless explicitly asked** -- they are resource-intensive and disruptive
