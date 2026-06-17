#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/rust"
case "$(uname -s)" in
  Darwin)
    # Universal dylib (Apple Silicon + Intel): build both targets and lipo
    # them together so the one shipped .app runs on either architecture.
    rustup target add aarch64-apple-darwin x86_64-apple-darwin
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    cd ..
    mkdir -p assets/native/macos
    lipo -create \
      rust/target/aarch64-apple-darwin/release/libyourssh_vnc.dylib \
      rust/target/x86_64-apple-darwin/release/libyourssh_vnc.dylib \
      -output assets/native/macos/libyourssh_vnc.dylib ;;
  Linux)
    cargo build --release
    cd ..
    mkdir -p assets/native/linux
    cp rust/target/release/libyourssh_vnc.so assets/native/linux/ ;;
esac
echo "yourssh_vnc native library built"
