# MQTee build tasks

# Build the Rust library and generate Swift bindings (XCFramework for macOS + iOS)
build-rust:
    cd rust && ./build-xcframework.sh

# Clean Rust build artifacts
clean-rust:
    cd rust && cargo clean
    rm -rf MQTeeCore

# Check Rust code
check-rust:
    cd rust && cargo check

# Run Rust tests
test-rust:
    cd rust && cargo test

# Format Rust code
fmt-rust:
    cd rust && cargo fmt

# Lint Rust code
lint-rust:
    cd rust && cargo clippy -- -D warnings

# Run Swift unit tests (macOS)
test-swift:
    xcodebuild test -project mqtee.xcodeproj -scheme mqtee -only-testing:mqteeTests -destination 'platform=macOS' -quiet

# Run Swift unit tests (iOS Simulator)
test-swift-ios:
    xcodebuild test -project mqtee.xcodeproj -scheme mqtee -only-testing:mqteeTests -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

# Run UI tests (macOS)
test-ui:
    xcodebuild test -project mqtee.xcodeproj -scheme mqtee -only-testing:mqteeUITests -destination 'platform=macOS' -quiet

# Run UI tests (iOS Simulator)
test-ui-ios:
    xcodebuild test -project mqtee.xcodeproj -scheme mqtee -only-testing:mqteeUITests -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

# Run integration tests with local broker
test-integration:
    mqteeIntegrationTests/run-with-broker.sh

# Run all non-network tests
test-all: test-rust test-swift

# Build for iOS (generic device)
build-ios:
    xcodebuild build -project mqtee.xcodeproj -scheme mqtee -destination 'generic/platform=iOS' -quiet

# Build for iOS Simulator
build-ios-sim:
    xcodebuild build -project mqtee.xcodeproj -scheme mqtee -destination 'generic/platform=iOS Simulator' -quiet

# Generate open source license bundle from Rust dependencies
generate-licenses:
    cd rust && cargo bundle-licenses --format json --output ../mqtee/Resources/licenses.json

# Run Swift performance benchmarks (XCTest measure blocks)
bench-swift:
    xcodebuild test -project mqtee.xcodeproj -scheme mqtee -only-testing:mqteeTests/TopicTreePerformanceTests -only-testing:mqteeTests/TopicMatchingPerformanceTests -only-testing:mqteeTests/PayloadDetectionPerformanceTests -only-testing:mqteeTests/JSONHighlighterPerformanceTests -only-testing:mqteeTests/MessageExportPerformanceTests -destination 'platform=macOS' -quiet

# Run Rust benchmarks (criterion)
bench-rust:
    cd rust && cargo bench

# Run all benchmarks
bench-all: bench-rust bench-swift

# Full rebuild
rebuild: clean-rust build-rust
