#!/usr/bin/env bash

# KCM Test Suite
# Tests core functionality and security features

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
SKIPPED=0

# Test environment
TEST_DIR=$(mktemp -d)
TEST_ENV="$TEST_DIR/.env"
TEST_KEY="TEST_KCM_KEY_$$"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kcm"

# Cleanup function
cleanup() {
    # Remove test keys from keychain (silently)
    security delete-generic-password -s "$TEST_KEY" >/dev/null 2>&1 || true
    security delete-generic-password -s "${TEST_KEY}_2" >/dev/null 2>&1 || true
    security delete-generic-password -s "${TEST_KEY}_QUOTE" >/dev/null 2>&1 || true
    security delete-generic-password -s "TEST_PATTERN_ONE" >/dev/null 2>&1 || true
    security delete-generic-password -s "TEST_PATTERN_TWO" >/dev/null 2>&1 || true
    security delete-generic-password -s "OTHER_PATTERN" >/dev/null 2>&1 || true

    # Remove test directory
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT INT TERM

# Test functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

skip() {
    echo -e "${YELLOW}⊘${NC} $1 (skipped)"
    ((SKIPPED++))
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        pass "$test_name"
    else
        fail "$test_name - Expected: '$expected', Got: '$actual'"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$test_name"
    else
        fail "$test_name - '$needle' not found in output"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$test_name"
    else
        fail "$test_name - '$needle' found in output (should not be)"
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" -eq "$actual" ]; then
        pass "$test_name"
    else
        fail "$test_name - Expected exit code: $expected, Got: $actual"
    fi
}

# Test Suite
echo "======================================"
echo "KCM Test Suite"
echo "======================================"
echo

# Test 1: Basic help command
echo "Test Group: Basic Commands"
echo "--------------------------"
output=$("$SCRIPT_PATH" help 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Help command exits successfully"
assert_contains "$output" "kcm - Keychain Master" "Help shows title"
assert_contains "$output" "USAGE:" "Help shows usage"

# Test 2: Version command
output=$("$SCRIPT_PATH" version 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Version command exits successfully"
assert_contains "$output" "kcm version" "Version shows output"

echo
echo "Test Group: Secret Management"
echo "-----------------------------"

# Test 3: Add secret
echo "test123" | "$SCRIPT_PATH" add "$TEST_KEY" - >/dev/null 2>&1 && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Add secret via stdin"

# Test 4: Show secret
output=$("$SCRIPT_PATH" show "$TEST_KEY" 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Show secret exits successfully"
assert_equals "test123" "$output" "Show returns correct secret value"

# Test 5: List secrets
output=$("$SCRIPT_PATH" ls 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "List command exits successfully"
assert_contains "$output" "$TEST_KEY" "List shows test key"

# Test 6: Remove secret
"$SCRIPT_PATH" remove "$TEST_KEY" >/dev/null 2>&1 && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Remove secret successfully"

# Test 7: Show non-existent secret
output=$("$SCRIPT_PATH" show "$TEST_KEY" 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 1 "$exit_code" "Show non-existent secret fails"

echo
echo "Test Group: Input Validation"
echo "----------------------------"

# Test 8: Invalid key name with special characters
output=$("$SCRIPT_PATH" add '$INVALID_KEY' 2>&1 <<< "value") && exit_code=$? || exit_code=$?
assert_exit_code 1 "$exit_code" "Reject key starting with $"

# Test 9: Invalid key name with numbers at start
output=$("$SCRIPT_PATH" add '123KEY' 2>&1 <<< "value") && exit_code=$? || exit_code=$?
assert_exit_code 1 "$exit_code" "Reject key starting with number"

# Test 10: Valid key with underscore
echo "underscore_value" | "$SCRIPT_PATH" add "${TEST_KEY}_2" - >/dev/null 2>&1 && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Accept key with underscore"
"$SCRIPT_PATH" remove "${TEST_KEY}_2" >/dev/null 2>&1

echo
echo "Test Group: Environment File Processing"
echo "---------------------------------------"

# Test 11: Create test .env file
cat > "$TEST_ENV" << EOF
SIMPLE_VAR=simple_value
DOUBLE_QUOTED="quoted value"
SINGLE_QUOTED='single quoted'
# This is a comment
EMPTY_VAR=
  # Indented comment
SPACES_AROUND = value with spaces
EXPORT_VAR=exported
export EXPORTED_VAR=exported_value
EOF

# Add a secret for keychain:// resolution
echo "keychain_secret" | "$SCRIPT_PATH" add "${TEST_KEY}_QUOTE" - >/dev/null 2>&1

# Test 12: Process env file with keychain reference
cat >> "$TEST_ENV" << EOF
KEYCHAIN_VAR=keychain://${TEST_KEY}_QUOTE
EOF

# Test 13: Use command with env file
output=$("$SCRIPT_PATH" use --env-file "$TEST_ENV" -- bash -c 'echo "$SIMPLE_VAR"' 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Use command with env file"
assert_equals "simple_value" "$output" "Simple variable resolved"

# Test 14: Quoted values
output=$("$SCRIPT_PATH" use --env-file "$TEST_ENV" -- bash -c 'echo "$DOUBLE_QUOTED"' 2>&1) && exit_code=$? || exit_code=$?
assert_equals "quoted value" "$output" "Double quoted value handled"

output=$("$SCRIPT_PATH" use --env-file "$TEST_ENV" -- bash -c 'echo "$SINGLE_QUOTED"' 2>&1) && exit_code=$? || exit_code=$?
assert_equals "single quoted" "$output" "Single quoted value handled"

# Test 15: Keychain resolution
output=$("$SCRIPT_PATH" use --env-file "$TEST_ENV" -- bash -c 'echo "$KEYCHAIN_VAR"' 2>&1) && exit_code=$? || exit_code=$?
assert_equals "keychain_secret" "$output" "Keychain reference resolved"

echo
echo "Test Group: Security Features"
echo "-----------------------------"

# Test 16: Dangerous characters without --allow-unsafe
cat > "$TEST_ENV" << 'EOF'
DANGEROUS_VAR=$HOME
BACKTICK_VAR=`echo bad`
SEMICOLON_VAR=value;echo bad
PIPE_VAR=value|echo bad
EOF

output=$("$SCRIPT_PATH" use --env-file "$TEST_ENV" -- bash -c 'echo "TEST"' 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Command runs despite dangerous vars"
assert_contains "$output" "potentially dangerous" "Warning about dangerous characters"

# Test 17: Allow unsafe flag
output=$("$SCRIPT_PATH" use --allow-unsafe --env-file "$TEST_ENV" -- bash -c 'echo "$DANGEROUS_VAR"' 2>&1) && exit_code=$? || exit_code=$?
assert_contains "$output" "\$HOME" "Dangerous var allowed with flag"

# Test 18: Path validation
output=$("$SCRIPT_PATH" use --env-file /etc/passwd -- echo test 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 1 "$exit_code" "Reject system file as env-file"
assert_contains "$output" "Security error" "Security error message shown"

echo
echo "Test Group: Edge Cases"
echo "----------------------"

# Test 19: Non-existent env file
output=$("$SCRIPT_PATH" use --env-file /nonexistent.env -- echo test 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Continue with non-existent env file"
assert_contains "$output" "not found" "Warning about missing file"

# Test 20: Empty env file
touch "$TEST_DIR/empty.env"
output=$("$SCRIPT_PATH" use --env-file "$TEST_DIR/empty.env" -- echo "works" 2>&1) && exit_code=$? || exit_code=$?
assert_exit_code 0 "$exit_code" "Handle empty env file"
assert_equals "works" "$output" "Command runs with empty env"

# Test 21: Malformed env entries
cat > "$TEST_ENV" << 'EOF'
NO_EQUALS_SIGN
=NO_VAR_NAME
VAR WITH SPACES=invalid
123_STARTS_WITH_NUMBER=invalid
VALID_VAR=valid_value
EOF

output=$("$SCRIPT_PATH" use --env-file "$TEST_ENV" -- bash -c 'echo "$VALID_VAR"' 2>&1) && exit_code=$? || exit_code=$?
assert_equals "valid_value" "$output" "Valid var processed despite malformed entries"

# Test 22: Command with arguments
output=$("$SCRIPT_PATH" use --env-file "$TEST_ENV" -- bash -c 'echo $1 $2' -- "arg1" "arg2" 2>&1) && exit_code=$? || exit_code=$?
assert_equals "arg1 arg2" "$output" "Arguments passed correctly"

echo
echo "Test Group: Pattern Matching"
echo "----------------------------"

# Add test secrets for pattern matching
echo "value1" | "$SCRIPT_PATH" add "TEST_PATTERN_ONE" - >/dev/null 2>&1
echo "value2" | "$SCRIPT_PATH" add "TEST_PATTERN_TWO" - >/dev/null 2>&1
echo "value3" | "$SCRIPT_PATH" add "OTHER_PATTERN" - >/dev/null 2>&1

# Test 23: List with pattern
output=$("$SCRIPT_PATH" ls "TEST_PATTERN*" 2>&1) && exit_code=$? || exit_code=$?
assert_contains "$output" "TEST_PATTERN_ONE" "Pattern matches first key"
assert_contains "$output" "TEST_PATTERN_TWO" "Pattern matches second key"
assert_not_contains "$output" "OTHER_PATTERN" "Pattern excludes non-matching"

# Cleanup pattern test keys
"$SCRIPT_PATH" remove "TEST_PATTERN_ONE" >/dev/null 2>&1
"$SCRIPT_PATH" remove "TEST_PATTERN_TWO" >/dev/null 2>&1
"$SCRIPT_PATH" remove "OTHER_PATTERN" >/dev/null 2>&1

echo
echo "======================================"
echo "Test Summary"
echo "======================================"
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi