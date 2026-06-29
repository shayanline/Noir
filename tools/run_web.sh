#!/usr/bin/env bash
# Serve the web export and open it in Safari for responsive testing.
#
# Usage:
#   ./tools/run_web.sh          # export + serve on port 8060
#   ./tools/run_web.sh --skip   # serve only (skip re-export)
#
# Once open, use Safari > Develop > Enter Responsive Design Mode (Ctrl+Cmd+R)
# to switch between iPhone, iPad, and desktop viewports.
#
# Requires the standard (non-mono) Godot for the web export.
# Set GODOT_STD to point at it if it is not in ~/Downloads/Godot.app.

set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_STD="${GODOT_STD:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
PORT="${PORT:-8060}"
BUILD_DIR="build/web"

if [[ "${1:-}" != "--skip" ]]; then
    echo "Exporting web build..."
    mkdir -p "$BUILD_DIR"
    "$GODOT_STD" --path . --headless --export-debug "Web" "$BUILD_DIR/index.html" 2>&1 | tail -3
    echo "Export done."
fi

if ! [[ -f "$BUILD_DIR/index.html" ]]; then
    echo "No web build found. Run without --skip first."
    exit 1
fi

echo "Serving at http://localhost:${PORT}"
echo "Open Safari, then Develop > Enter Responsive Design Mode (Ctrl+Cmd+R)"
echo "Press Ctrl+C to stop."

# SharedArrayBuffer requires cross-origin isolation headers
python3 -c "
import http.server, functools, sys, os

class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

os.chdir('${BUILD_DIR}')
srv = http.server.HTTPServer(('', ${PORT}), CORSHandler)
print(f'Listening on http://localhost:${PORT}')
srv.serve_forever()
" &
SERVER_PID=$!

sleep 1
open "http://localhost:${PORT}"

trap "kill $SERVER_PID 2>/dev/null" EXIT
wait $SERVER_PID
