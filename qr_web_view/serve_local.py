#!/usr/bin/env python3
"""
Simple HTTP server for Flutter web app with SPA routing support.
Serves index.html for all routes to enable client-side routing.
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

class SPAHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler that serves index.html for all routes (SPA routing)"""
    
    def end_headers(self):
        # Add CORS headers for local testing
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        # Prevent caching of index.html
        if self.path == '/' or self.path.startswith('/stats') or self.path.startswith('/?'):
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
        super().end_headers()
    
    def do_GET(self):
        # If it's a file that exists, serve it normally
        if self.path != '/' and not self.path.startswith('/stats') and not self.path.startswith('/?'):
            # Check if it's a real file
            file_path = Path(self.directory) / self.path.lstrip('/')
            if file_path.exists() and file_path.is_file():
                return super().do_GET()
        
        # For all other routes (including /stats), serve index.html
        # This enables client-side routing
        self.path = '/index.html'
        return super().do_GET()
    
    def log_message(self, format, *args):
        # Custom logging to show what's being served
        if args[0].startswith('GET /stats') or args[0].startswith('GET /?'):
            super().log_message(format, *args)
        elif not args[0].startswith('GET /assets') and not args[0].startswith('GET /canvaskit'):
            super().log_message(format, *args)

def main():
    # Get the directory where this script is located
    script_dir = Path(__file__).parent.absolute()
    build_dir = script_dir / 'build' / 'web'
    
    # Check if build directory exists
    if not build_dir.exists():
        print(f"❌ Build directory not found: {build_dir}")
        print("Please run: flutter build web --release")
        sys.exit(1)
    
    # Change to build directory
    os.chdir(build_dir)
    
    # Get port from command line or use default
    port = 8000
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port: {sys.argv[1]}. Using default port 8000")
    
    # Get local IP address
    import socket
    hostname = socket.gethostname()
    try:
        local_ip = socket.gethostbyname(hostname)
        # Try to get a better IP (not 127.0.0.1)
        if local_ip == '127.0.0.1':
            # Try to get actual network IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
    except:
        local_ip = "localhost"
    
    # Create server
    handler = SPAHTTPRequestHandler
    handler.directory = str(build_dir)
    
    with socketserver.TCPServer(("0.0.0.0", port), handler) as httpd:
        print("\n" + "="*60)
        print("🚀 Flutter Web App - Local Server")
        print("="*60)
        print(f"\n📍 Local URLs:")
        print(f"   http://localhost:{port}")
        print(f"   http://127.0.0.1:{port}")
        if local_ip != "127.0.0.1" and local_ip != "localhost":
            print(f"\n📍 Mobile Device URLs (same Wi-Fi):")
            print(f"   http://{local_ip}:{port}")
            print(f"   http://{local_ip}:{port}/stats")
        print(f"\n📍 Test Routes:")
        print(f"   http://localhost:{port}/")
        print(f"   http://localhost:{port}/stats")
        print(f"   http://localhost:{port}/?qr_token=test123")
        print("\n" + "="*60)
        print("Press Ctrl+C to stop the server")
        print("="*60 + "\n")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n👋 Server stopped")

if __name__ == "__main__":
    main()

