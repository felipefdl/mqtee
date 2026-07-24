<br/>
<p align="center">
  <img src="assets/logo.png" width="200px" alt="Mqtee"></img>
</p>

# Mqtee

Native multi-platform MQTT client for macOS, iOS, and iPadOS. SwiftUI UI over a Rust MQTT core.

---

## Features

- **MQTT 3.1.1 and 5.0**: QoS 0, 1, and 2
- **TLS**: CA validation, client certificates, and insecure mode
- **Topic tree**: hierarchical browsing with color-coded subscriptions
- **MQTT 5 options**: noLocal, retainAsPublished, retainHandling
- **Multi-tab publish**: text, JSON, and hex payloads
- **Session persistence**: subscriptions and message history across reconnects
- **Last Will and Testament**: per-connection LWT configuration
- **Event log**: filter by level, category, and direction
- **iCloud sync**: connections and Keychain credentials across devices
- **Import and export**: connection backup and sharing
- **Shortcuts and Siri**: publish messages and read retained values
- **License attribution**: bundled open source dependency list

## Requirements

- macOS 26.0+ / iOS 26.0+ / iPadOS 26.0+
- Xcode 26.0+
- Swift 6.0+
- Rust 1.85.0+ (edition 2024)
- `just` (`brew install just`)
- `cargo-bundle-licenses` (`cargo install cargo-bundle-licenses`)

## Quick Start

```sh
just build-rust
open mqtee.xcodeproj
```

Build and run the `mqtee` scheme in Xcode (Mac or iOS Simulator).

## Commands

```sh
just build-rust       # Rust XCFramework + UniFFI Swift bindings
just clean-rust       # Clean Rust artifacts and MQTeeCore
just check-rust       # cargo check
just test-rust        # cargo test
just test-swift       # Swift unit tests (macOS)
just test-all         # Rust + Swift unit tests
just lint-rust        # cargo clippy -D warnings
just fmt-rust         # cargo fmt
just rebuild          # Full clean + build
```

Optional: `just test-ui`, `just test-swift-ios`, `just test-integration`, `just generate-licenses`. See `justfile` and root `AGENTS.md` for more.

## Project structure

```
mqtee/                 # SwiftUI app (Models, Views, Services, Design, Intents)
rust/                  # MQTT core + UniFFI (rumqttc, tokio, rustls)
MQTeeCore/             # Generated XCFramework (not committed; build with just build-rust)
mqteeTests/            # Swift Testing unit tests
mqteeUITests/          # XCTest UI tests
mqteeIntegrationTests/ # Integration tests against a local rumqttd broker
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

This repository is licensed under the [Apache License 2.0](LICENSE.md).

### Copyright Notice

Felipe Lima retains rights to the Mqtee name, logo, and branding assets. Those materials are not covered by the Apache License 2.0. See [LICENSE.md](LICENSE.md#copyright-notice).

### Third-party components

Third-party crates and packages keep their own licenses. See `mqtee/Resources/licenses.json` and `rust/Cargo.toml`.

---

Built by [Felipe Lima](https://github.com/felipefdl). Software licensed under [Apache-2.0](LICENSE.md). Mqtee logos and branding are not covered by Apache-2.0; see [Copyright Notice](LICENSE.md#copyright-notice) in LICENSE.md.
