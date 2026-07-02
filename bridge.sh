#!/bin/sh
# mediamtx runOnReady bridge: forward a WHIP/WebRTC path to the existing nginx-rtmp ingest.
# mediamtx percent-encodes '=' in $MTX_QUERY (key%3D...), so URL-decode it before handing
# the publish key to nginx-rtmp. $1 = MTX_PATH (channel), $2 = MTX_QUERY (?key=<key>).
path="$1"
query=$(printf '%s' "$2" | sed 's/%3D/=/g; s/%26/\&/g')
exec ffmpeg -nostdin -hide_banner -loglevel warning \
  -rtsp_transport tcp -i "rtsp://localhost:8554/$path" \
  -c:v copy -c:a aac -ar 44100 -b:a 128k \
  -f flv "rtmp://rtmp.live.svc.cluster.local:1935/odeon/$path?$query"
