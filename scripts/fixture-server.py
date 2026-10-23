#!/usr/bin/env python3
"""Local-only deterministic pages for native browser acceptance. No external resources."""
import argparse
import html
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/redirect':
            self.send_response(302); self.send_header('Location', '/second'); self.end_headers(); return
        if parsed.path == '/download':
            body = b'choco acceptance download\n'
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.send_header('Content-Disposition', 'attachment; filename="acceptance.txt"')
        else:
            title, content = 'Acceptance Home', '''<h1>Acceptance Home</h1>
<p>WebKit acceptance fixture. No external requests.</p>
<a href="/second">Second page</a> <a href="/redirect">Redirect</a>
<a href="/child" target="_blank">Open child tab</a>
<button onclick="window.open('/child', 'child')">Open popup</button>
<button onclick="alert('Acceptance alert')">Show alert</button>
<button onclick="document.getElementById('result').textContent=confirm('Acceptance confirm')">Show confirm</button>
<input aria-label="Page input" placeholder="Type here"><input type="file" aria-label="Upload file">
<a href="/download">Download test file</a><a href="/cookie">Read cookies</a>
<div id="result"></div>'''
            if parsed.path == '/second':
                title, content = 'Acceptance Second', '<h1>Acceptance Second</h1><a href="/">Home</a><p>Searchable needle 日本語テスト</p>'
            elif parsed.path == '/child':
                title, content = 'Acceptance Child', '<h1>Acceptance Child</h1><button onclick="window.close()">Close child</button>'
            elif parsed.path == '/set-cookie':
                title, content = 'Acceptance Cookie Set', '<h1>Acceptance Cookie Set</h1><a href="/cookie">Read cookies</a>'
            elif parsed.path == '/cookie':
                title, content = 'Acceptance Cookies', '<h1>Acceptance Cookies</h1><p>Cookie echo: ' + html.escape(self.headers.get('Cookie', '(none)')) + '</p>'
            body = (f'<!doctype html><html lang="en"><meta charset="utf-8"><title>{title}</title><style>body{{font:18px system-ui;margin:40px;line-height:1.7}}a,button,input{{margin:8px}}</style>{content}</html>').encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            if parsed.path == '/set-cookie':
                value = parse_qs(parsed.query).get('value', ['fixture'])[0]
                if value.isalnum(): self.send_header('Set-Cookie', 'session=' + value + '; Path=/; Max-Age=600; HttpOnly; SameSite=Lax')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers(); self.wfile.write(body)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Fixture server: http://127.0.0.1:{server.server_port}', flush=True)
    server.serve_forever()
