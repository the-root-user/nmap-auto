#!/usr/bin/env bash
#
# Automated test suite for nmap-auto.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SCRIPT_DIR}/nmap-auto.sh"

FAILED=0
PASSED=0

assert_contains() {
    local text="$1"
    local substring="$2"
    local test_name="$3"

    if [[ "$text" == *"$substring"* ]]; then
        echo "[PASS] $test_name"
        PASSED=$((PASSED + 1))
    else
        echo "[FAIL] $test_name (Expected substring '$substring' not found)"
        FAILED=$((FAILED + 1))
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [[ "$expected" -eq "$actual" ]]; then
        echo "[PASS] $test_name (exit code: $actual)"
        PASSED=$((PASSED + 1))
    else
        echo "[FAIL] $test_name (Expected exit code $expected, got $actual)"
        FAILED=$((FAILED + 1))
    fi
}

echo "=== Running Tests for nmap-auto ==="

# Test 1: Help message
output=$("$SCRIPT" --help)
assert_contains "$output" "Usage: sudo nmap-auto.sh [OPTIONS] <target>" "Test --help output"

# Test 2: Version
output=$("$SCRIPT" --version)
assert_contains "$output" "nmap-auto v" "Test --version output"

# Test 3: Missing target argument error
set +e
output=$("$SCRIPT" 2>&1)
code=$?
set -e
assert_exit_code 1 "$code" "Test missing target exit code"
assert_contains "$output" "Missing required target argument" "Test missing target error message"

# Test 4: Invalid option error
set +e
output=$("$SCRIPT" --invalid-flag 2>&1)
code=$?
set -e
assert_exit_code 1 "$code" "Test unknown option exit code"
assert_contains "$output" "Unknown option: --invalid-flag" "Test unknown option error message"

# Test 5: Invalid rate argument
set +e
output=$("$SCRIPT" -r notanumber 127.0.0.1 2>&1)
code=$?
set -e
assert_exit_code 1 "$code" "Test invalid rate exit code"
assert_contains "$output" "requires a positive integer rate" "Test invalid rate error message"

# Test 6: Invalid timing argument
set +e
output=$("$SCRIPT" -T 9 127.0.0.1 2>&1)
code=$?
set -e
assert_exit_code 1 "$code" "Test invalid timing exit code"
assert_contains "$output" "requires a timing template between 0 and 5" "Test invalid timing error message"

# Test 7: Output directory creation and scanning with mock
TEST_OUTPUT_DIR=$(mktemp -d)

# Start a mock open port
python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(('127.0.0.1', 19999))
s.listen(5)
time.sleep(10)
" &
MOCK_PID=$!
sleep 1

set +e
output=$(sudo "$SCRIPT" -o "$TEST_OUTPUT_DIR" -p 19999 --no-udp --no-color 127.0.0.1 2>&1)
code=$?
set -e

kill "$MOCK_PID" 2>/dev/null || true

assert_exit_code 0 "$code" "Test scan execution exit code"
assert_contains "$output" "Discovered open port: 19999/tcp" "Test port discovery output"
assert_contains "$output" "TCP Service Scan completed" "Test TCP service scan completed"

# Verify output file was created
if [[ -f "${TEST_OUTPUT_DIR}/127.0.0.1_scan_result_tcp.txt" ]]; then
    echo "[PASS] Test output file generated successfully"
    PASSED=$((PASSED + 1))
else
    echo "[FAIL] Test output file was not generated"
    FAILED=$((FAILED + 1))
fi

rm -rf "$TEST_OUTPUT_DIR"

echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -ne 0 ]]; then
    exit 1
fi
