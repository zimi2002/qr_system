#!/bin/bash
set -e

# Vercel Build Script for Flutter Web
# This script installs Flutter if needed and builds the web app

echo "🚀 Starting Flutter web build..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "📦 Flutter not found, installing..."
    
    # Install Flutter
    FLUTTER_VERSION="stable"
    git clone https://github.com/flutter/flutter.git -b $FLUTTER_VERSION --depth 1
    export PATH="$PATH:`pwd`/flutter/bin"
    
    # Accept licenses
    flutter doctor --android-licenses || true
    
    echo "✅ Flutter installed"
fi

# Verify Flutter installation
flutter --version
flutter doctor

# Get dependencies
echo "📥 Getting Flutter dependencies..."
flutter pub get

# Build web app
echo "🔨 Building web app..."
flutter build web --release

echo "✅ Build complete! Output in build/web/"

