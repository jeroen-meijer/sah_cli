#!/usr/bin/env bash

set -e

# 0. Check if build/.build_hash exists
# 1. Calculate hashes of all dart files in lib/ + bin/ and pubspec.yaml
# 2. Compare hashes to previous hashes (if previous hashes exist)
# 3. If hashes are different or we had no hash file, compile sah
# 4. If hashes are the same, use existing binary

THIS_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
pushd "$THIS_SCRIPT_DIR" > /dev/null

print_grey() {
    echo -e "\033[90m$1\033[0m"
}

mkdir -p build

calculate_hash() {
    find . \( -name "*.dart" \( -path "*/lib/*" -o -path "*/bin/*" \) \) -o -name "pubspec.yaml" \
        | sort | xargs sha256sum | sha256sum | cut -d' ' -f1
}

CURRENT_HASH=$(calculate_hash)

BUILD_HASH_FILE="build/.build_hash"
if [ -f "$BUILD_HASH_FILE" ]; then
    PREVIOUS_HASH=$(cat "$BUILD_HASH_FILE")
else
    PREVIOUS_HASH=""
fi

BINARY_PATH="build/sah"
BINARY_EXISTS=false
if [ -f "$BINARY_PATH" ]; then
    BINARY_EXISTS=true
fi

if [ "$CURRENT_HASH" != "$PREVIOUS_HASH" ] || [ ! -f "$BUILD_HASH_FILE" ] || [ "$BINARY_EXISTS" = false ]; then
    print_grey "Compiling sah..."

    dart pub get
    dart compile exe bin/sah.dart -o "$BINARY_PATH"

    echo "$CURRENT_HASH" > "$BUILD_HASH_FILE"

    print_grey "Compilation complete."
fi

"$BINARY_PATH" "$@"

popd > /dev/null
