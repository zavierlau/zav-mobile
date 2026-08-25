#!/bin/bash
# Build ZAV mobile web with injected token.
set -e
cd /home/zav/zav_mobile
TOK=$(grep -E '^CONTROL_TOKEN=' /home/zav/zav-ai-dashboard/.env.local | head -1 | cut -d= -f2 | tr -d '"')
export PATH="/opt/flutter/bin:$PATH"
flutter build web --dart-define=ZAV_TOKEN="$TOK"
echo "built with token"