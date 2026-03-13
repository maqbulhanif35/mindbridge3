#!/bin/bash
set -e

echo "=== Installing Flutter ==="
git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter config --enable-web
flutter --version

echo "=== Creating .env from Netlify environment ==="
printf "GROQ_API_KEY=%s\n" "${GROQ_API_KEY}" > .env

echo "=== Installing dependencies ==="
flutter pub get

echo "=== Building for web ==="
flutter build web --release --dart-define=GROQ_API_KEY="${GROQ_API_KEY}"

echo "=== Done ==="
