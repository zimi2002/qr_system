#!/bin/bash
set -e

# Vercel Build Script for Flutter Web
# This script installs Flutter if needed and builds the web app

echo "🚀 Starting Flutter web build..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "📦 Flutter not found, installing..."
    
    # Install Flutter to a local directory
    FLUTTER_VERSION="stable"
    FLUTTER_DIR="$HOME/flutter"
    
    if [ ! -d "$FLUTTER_DIR" ]; then
        git clone https://github.com/flutter/flutter.git -b $FLUTTER_VERSION --depth 1 $FLUTTER_DIR
    fi
    
    export PATH="$PATH:$FLUTTER_DIR/bin"
    
    # Precache web dependencies
    $FLUTTER_DIR/bin/flutter precache --web
    
    echo "✅ Flutter installed"
fi

# Verify Flutter installation
flutter --version

# Get dependencies
echo "📥 Getting Flutter dependencies..."
flutter pub get

# Build web app
echo "🔨 Building web app..."
flutter build web --release

echo "✅ Build complete! Output in build/web/"

