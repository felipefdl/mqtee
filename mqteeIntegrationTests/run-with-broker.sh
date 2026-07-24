#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RUST_DIR="$PROJECT_DIR/rust"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
BROKER_PID=""
TEMP_DIR=""

cleanup() {
    if [ -n "$BROKER_PID" ] && kill -0 "$BROKER_PID" 2>/dev/null; then
        echo "Stopping test broker (PID $BROKER_PID)..."
        kill "$BROKER_PID" 2>/dev/null || true
        wait "$BROKER_PID" 2>/dev/null || true
    fi
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    rm -rf "$FIXTURES_DIR"
}

trap cleanup EXIT

echo "=== Integration Test Runner ==="
echo ""

# 0. Check for stale processes on test ports
for PORT in 18830 18831; do
    STALE_PID=$(lsof -ti :$PORT -sTCP:LISTEN 2>/dev/null || true)
    if [ -n "$STALE_PID" ]; then
        echo "Killing stale process on port $PORT (PID $STALE_PID)..."
        kill "$STALE_PID" 2>/dev/null || true
        sleep 1
    fi
done

# 1. Create temp directory for TLS certs
TEMP_DIR="$(mktemp -d)"
echo "Generating TLS certificates in $TEMP_DIR..."

# 2. Generate self-signed certs
# CA
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TEMP_DIR/ca.key" \
    -out "$TEMP_DIR/ca.pem" \
    -days 1 \
    -subj "/CN=MQTee Test CA" \
    2>/dev/null

# Server cert signed by CA
openssl req -newkey rsa:2048 -nodes \
    -keyout "$TEMP_DIR/server.key" \
    -out "$TEMP_DIR/server.csr" \
    -subj "/CN=localhost" \
    2>/dev/null

openssl x509 -req \
    -in "$TEMP_DIR/server.csr" \
    -CA "$TEMP_DIR/ca.pem" \
    -CAkey "$TEMP_DIR/ca.key" \
    -CAcreateserial \
    -out "$TEMP_DIR/server.pem" \
    -days 1 \
    -extfile <(printf "subjectAltName=IP:127.0.0.1,DNS:localhost") \
    2>/dev/null

echo "Certificates generated."

# 3. Build test broker
echo ""
echo "Building test broker..."
cd "$RUST_DIR"
cargo build --bin test-broker --features test-broker 2>&1

# 4. Start broker in background
echo ""
echo "Starting test broker..."
"$RUST_DIR/target/debug/test-broker" \
    "$TEMP_DIR/server.pem" "$TEMP_DIR/server.key" &
BROKER_PID=$!

# 5. Wait for broker to be ready
TIMEOUT=15
WAITED=0
READY=false

while [ "$WAITED" -lt "$TIMEOUT" ]; do
    if ! kill -0 "$BROKER_PID" 2>/dev/null; then
        echo "ERROR: Broker process exited unexpectedly"
        exit 1
    fi
    # Check if broker port is listening
    if lsof -i :18830 -sTCP:LISTEN >/dev/null 2>&1; then
        READY=true
        break
    fi
    sleep 1
    WAITED=$((WAITED + 1))
done

if [ "$READY" != "true" ]; then
    echo "ERROR: Broker did not start within ${TIMEOUT}s"
    exit 1
fi

echo "Broker ready (PID $BROKER_PID)"

# 6. Copy CA cert to fixtures for tests (if needed in future)
mkdir -p "$FIXTURES_DIR"
cp "$TEMP_DIR/ca.pem" "$FIXTURES_DIR/ca.pem"

# 7. Run integration tests
echo ""
echo "Running integration tests..."
cd "$PROJECT_DIR"
TEST_EXIT=0
xcodebuild test \
    -project mqtee.xcodeproj \
    -scheme mqtee \
    -only-testing:mqteeIntegrationTests \
    -destination 'platform=macOS' \
    -quiet || TEST_EXIT=$?

# 8. Cleanup handled by trap
echo ""
if [ "$TEST_EXIT" -eq 0 ]; then
    echo "=== All integration tests passed ==="
else
    echo "=== Integration tests failed (exit code $TEST_EXIT) ==="
fi

exit $TEST_EXIT
