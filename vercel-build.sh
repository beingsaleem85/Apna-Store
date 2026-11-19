#!/bin/bash
set -e

echo "=== Installing Flutter SDK ==="
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
fi

export PATH="$HOME/flutter/bin:$PATH"

echo "=== Flutter Environment ==="
flutter config --no-analytics
flutter --version

echo "=== Building Flutter Web Release ==="
flutter build web --release

echo "=== Build Complete ==="
