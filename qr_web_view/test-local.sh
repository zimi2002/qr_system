#!/bin/bash

# Local Testing Script for Flutter Web App
# This script builds the app and serves it locally for testing

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Flutter Web Local Testing Script${NC}\n"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${YELLOW}❌ Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Build the web app
echo -e "${BLUE}📦 Building Flutter web app...${NC}"
flutter build web --release

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}\n"

# Get local IP address
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "localhost")
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
else
    LOCAL_IP="localhost"
fi

# Check for available server (prefer custom Python script for SPA routing)
SERVER_CMD=""
PORT=8000
USE_CUSTOM_PYTHON=false

# Check if custom Python server script exists
if [ -f "serve_local.py" ] && command -v python3 &> /dev/null; then
    SERVER_CMD="python3 serve_local.py $PORT"
    USE_CUSTOM_PYTHON=true
    echo -e "${BLUE}🌐 Starting Python server with SPA routing support...${NC}"
elif command -v python3 &> /dev/null; then
    echo -e "${YELLOW}⚠️  Using simple Python server - routes like /stats won't work!${NC}"
    echo -e "${YELLOW}   Consider using serve_local.py for proper routing support${NC}"
    SERVER_CMD="python3 -m http.server $PORT --bind 0.0.0.0"
    echo -e "${BLUE}🌐 Starting Python HTTP server...${NC}"
    cd build/web
elif command -v python &> /dev/null; then
    echo -e "${YELLOW}⚠️  Using simple Python server - routes like /stats won't work!${NC}"
    SERVER_CMD="python -m SimpleHTTPServer $PORT"
    echo -e "${BLUE}🌐 Starting Python HTTP server...${NC}"
    cd build/web
elif command -v php &> /dev/null; then
    SERVER_CMD="php -S 0.0.0.0:$PORT"
    echo -e "${BLUE}🌐 Starting PHP server...${NC}"
    cd build/web
elif command -v http-server &> /dev/null; then
    SERVER_CMD="http-server -p $PORT -a 0.0.0.0"
    echo -e "${BLUE}🌐 Starting Node.js http-server...${NC}"
    cd build/web
else
    echo -e "${YELLOW}❌ No suitable server found!${NC}"
    echo -e "${YELLOW}Please install one of: python3, php, or http-server (npm install -g http-server)${NC}"
    exit 1
fi

# Don't change directory if using custom Python script (it handles it)
if [ "$USE_CUSTOM_PYTHON" = false ]; then
    # Already changed above for other servers
    :
fi

echo -e "\n${GREEN}✅ Server starting...${NC}\n"
echo -e "${BLUE}📍 Local URLs:${NC}"
echo -e "   ${GREEN}http://localhost:$PORT${NC}"
echo -e "   ${GREEN}http://127.0.0.1:$PORT${NC}"

if [ "$LOCAL_IP" != "localhost" ]; then
    echo -e "\n${BLUE}📍 Mobile Device URLs (same Wi-Fi):${NC}"
    echo -e "   ${GREEN}http://$LOCAL_IP:$PORT${NC}"
    echo -e "   ${GREEN}http://$LOCAL_IP:$PORT/stats${NC}"
fi

echo -e "\n${YELLOW}Press Ctrl+C to stop the server${NC}\n"

# Start the server
exec $SERVER_CMD

