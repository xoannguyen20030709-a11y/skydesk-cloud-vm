#!/usr/bin/env python3
import http.server
import socketserver
import json
import os
import sys

PORT = 8080

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SkyDesk Cloud PC - In-Browser Web Console</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Inter', sans-serif; background: #0a0d14; color: #f3f4f6; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 20px; }
        .card { background: #111726; border: 1px solid #1f293d; border-radius: 16px; max-width: 680px; width: 100%; padding: 32px; box-shadow: 0 20px 40px rgba(0,0,0,0.6); }
        .header { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; }
        .badge { background: #10b98120; color: #10b981; border: 1px solid #10b98150; padding: 4px 12px; border-radius: 9999px; font-size: 13px; font-weight: 600; }
        h1 { font-size: 24px; font-weight: 700; color: #ffffff; }
        p { color: #9ca3af; font-size: 14px; line-height: 1.6; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 24px 0; }
        .info-box { background: #0a0d14; border: 1px solid #1f293d; padding: 14px; border-radius: 10px; }
        .info-label { font-size: 11px; text-transform: uppercase; color: #6b7280; font-weight: 600; letter-spacing: 0.5px; }
        .info-val { font-family: 'JetBrains Mono', monospace; font-size: 15px; color: #38bdf8; margin-top: 4px; word-break: break-all; }
        .btn-group { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 24px; }
        .btn { display: inline-flex; align-items: center; justify-content: center; padding: 12px 20px; border-radius: 10px; font-weight: 600; font-size: 14px; text-decoration: none; cursor: pointer; transition: all 0.2s; border: none; }
        .btn-primary { background: #4f46e5; color: #fff; }
        .btn-primary:hover { background: #4338ca; }
        .btn-secondary { background: #1f293d; color: #e5e7eb; border: 1px solid #374151; }
        .btn-secondary:hover { background: #374151; }
    </style>
</head>
<body>
    <div class="card">
        <div class="header">
            <span class="badge">● ONLINE</span>
            <h1>SkyDesk Cloud PC</h1>
        </div>
        <p>Windows Server Cloud Virtual Machine is active and running high-performance workloads for students and developers.</p>
        
        <div class="info-grid">
            <div class="info-box">
                <div class="info-label">Username</div>
                <div class="info-val">runneradmin</div>
            </div>
            <div class="info-box">
                <div class="info-label">Password</div>
                <div class="info-val">__PASSWORD__</div>
            </div>
            <div class="info-box">
                <div class="info-label">Direct RDP Host</div>
                <div class="info-val">__RDP_HOST__</div>
            </div>
            <div class="info-box">
                <div class="info-label">Local Port</div>
                <div class="info-val">3389 (RDP) / 8080 (Web)</div>
            </div>
        </div>

        <div class="btn-group">
            <a href="/download-rdp" class="btn btn-primary">⬇ Download .RDP Profile</a>
            <button onclick="navigator.clipboard.writeText('__PASSWORD__'); alert('Password copied to clipboard!');" class="btn btn-secondary">📋 Copy Password</button>
        </div>
    </div>
</body>
</html>
"""

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        password = "Password123!"
        rdp_host = "127.0.0.1:3389"
        
        config_path = "C:\\SkyDesk\\vm_info.json"
        if os.path.exists(config_path):
            try:
                with open(config_path, "r", encoding="utf-8") as f:
                    cfg = json.load(f)
                    password = cfg.get("password", password)
                    rdp_host = cfg.get("rdp_host", rdp_host)
            except Exception:
                pass

        if self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            html = HTML_TEMPLATE.replace('__PASSWORD__', password).replace('__RDP_HOST__', rdp_host)
            self.wfile.write(html.encode('utf-8'))
        elif self.path == '/download-rdp':
            rdp = f"full address:s:{rdp_host}\r\nusername:s:runneradmin\r\nprompt for credentials:i:1\r\nscreen mode id:i:2\r\ndesktopwidth:i:1920\r\ndesktopheight:i:1080\r\nsession bpp:i:32\r\nauthentication level:i:2\r\n"
            self.send_response(200)
            self.send_header('Content-type', 'application/x-rdp')
            self.send_header('Content-Disposition', 'attachment; filename="SkyDesk-CloudVM.rdp"')
            self.end_headers()
            self.wfile.write(rdp.encode('utf-8'))
        elif self.path == '/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "active", "rdp": rdp_host}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        print(f"SkyDesk Web Gateway running on port {PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    run_server()
