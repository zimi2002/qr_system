# Local Testing Guide

This guide shows you how to build and test the Flutter web app locally on your computer and mobile device.

## Quick Start

### 1. Build the Web App

```bash
cd qr_web_view
flutter build web --release
```

The built files will be in `build/web/`

### 2. Serve Locally

Choose one of the methods below to serve the app:

## Method 1: Using Python with SPA Routing Support (Recommended)

### Use the Custom Server Script (Handles Routes Correctly)
```bash
cd qr_web_view
python3 serve_local.py
```

This script automatically:
- Serves `index.html` for all routes (enables `/stats` to work)
- Shows your local IP for mobile testing
- Prevents caching issues

### Python 3 Simple Server (Routes won't work)
```bash
cd build/web
python3 -m http.server 8000
```
⚠️ **Note**: This won't work for `/stats` route - use `serve_local.py` instead!

### Python 2
```bash
cd build/web
python -m SimpleHTTPServer 8000
```
⚠️ **Note**: This won't work for `/stats` route - use `serve_local.py` instead!

## Method 2: Using Node.js (http-server)

### Install http-server globally:
```bash
npm install -g http-server
```

### Serve the app:
```bash
cd build/web
http-server -p 8000
```

## Method 3: Using Flutter's Built-in Server

```bash
cd qr_web_view
flutter run -d web-server --web-port 8000
```

Note: This runs in debug mode, not production build.

## Method 4: Using PHP

```bash
cd build/web
php -S localhost:8000
```

## Testing on Your Mobile Device

### Step 1: Find Your Computer's IP Address

**On Mac/Linux:**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
# or
ipconfig getifaddr en0
```

**On Windows:**
```bash
ipconfig
# Look for IPv4 Address under your active network adapter
```

You'll get something like: `192.168.1.100`

### Step 2: Start the Server

Make sure to bind to `0.0.0.0` so it's accessible from other devices:

**Python 3:**
```bash
cd build/web
python3 -m http.server 8000 --bind 0.0.0.0
```

**Node.js http-server:**
```bash
cd build/web
http-server -p 8000 -a 0.0.0.0
```

**PHP:**
```bash
cd build/web
php -S 0.0.0.0:8000
```

### Step 3: Access from Mobile Device

1. Make sure your phone/tablet is on the **same Wi-Fi network** as your computer
2. Open a browser on your device
3. Navigate to: `http://YOUR_IP_ADDRESS:8000`
   - Example: `http://192.168.1.100:8000`

### Step 4: Test Routes

- Main page: `http://YOUR_IP:8000/`
- Stats page: `http://YOUR_IP:8000/stats`
- With QR token: `http://YOUR_IP:8000/?qr_token=YOUR_TOKEN`

## Using the Helper Script

I've created a helper script to make this easier. See `test-local.sh` below.

## Troubleshooting

### Can't access from mobile device?

1. **Check firewall**: Make sure your firewall allows connections on port 8000
2. **Check network**: Ensure both devices are on the same Wi-Fi network
3. **Try different port**: Use port 8080 or 3000 if 8000 is blocked
4. **Check IP address**: Make sure you're using the correct IP (not 127.0.0.1)

### Firewall Settings

**Mac:**
- System Preferences → Security & Privacy → Firewall
- Make sure it's not blocking the connection

**Windows:**
- Windows Defender Firewall → Allow an app through firewall
- Add Python/Node.js/PHP to allowed apps

### Port Already in Use?

If port 8000 is busy, use a different port:
```bash
python3 -m http.server 8080 --bind 0.0.0.0
# Then access: http://YOUR_IP:8080
```

## Testing Production Build vs Development

### Production Build (Recommended for testing)
```bash
flutter build web --release
cd build/web
python3 -m http.server 8000 --bind 0.0.0.0
```

### Development Mode (Hot reload, but slower)
```bash
flutter run -d chrome --web-port 8000
```

## Testing Different Routes

Once the server is running, test these URLs:

1. **Main page**: `http://localhost:8000/` or `http://YOUR_IP:8000/`
2. **Stats page**: `http://localhost:8000/stats` or `http://YOUR_IP:8000/stats`
3. **With QR token**: `http://localhost:8000/?qr_token=test123`

## Quick Test Script

Run this to quickly build and serve:

```bash
cd qr_web_view
flutter build web --release && cd build/web && python3 -m http.server 8000 --bind 0.0.0.0
```

