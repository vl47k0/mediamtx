#!/bin/sh
# mediamtx runOnReady bridge: forward a WHIP/WebRTC path to the existing nginx-rtmp ingest.
# mediamtx percent-encodes '=' in $MTX_QUERY (key%3D...), so URL-decode it before handing
# the publish key to nginx-rtmp. $1 = MTX_PATH (channel), $2 = MTX_QUERY (?key=<key>).
path="$1"
query=$(printf '%s' "$2" | sed 's/%3D/=/g; s/%26/\&/g')
# Re-encode video (browser WebRTC keyframes are sparse/irregular) to fixed 30fps CFR with a
# closed 2s GOP and IDRs forced at exactly t=0,2,4..., matching nginx-rtmp's dash_fragment 2s so
# DASH segments are keyframe-aligned and dash.js playback stays smooth.
exec ffmpeg -nostdin -hide_banner -loglevel warning \
  -rtsp_transport tcp -i "rtsp://localhost:8554/$path" \
  -r 30 -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p \
  -b:v 2500k -maxrate 2500k -bufsize 5000k \
  -g 60 -keyint_min 60 -sc_threshold 0 -force_key_frames 'expr:gte(t,n_forced*2)' \
  -c:a aac -ar 44100 -b:a 128k \
  -f flv "rtmp://rtmp.live.svc.cluster.local:1935/odeon/$path?$query"
