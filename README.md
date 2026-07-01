# mediamtx — WHIP webcam ingest

A [mediamtx](https://github.com/bluenviron/mediamtx) instance that lets browsers stream their
**webcam** into Salon Live, without touching the rest of the pipeline.

## Why

The platform ingests RTMP (OBS/ffmpeg). Browsers can't speak RTMP, so webcam-from-the-browser
needs a WebRTC front-end. mediamtx accepts **WHIP** (WebRTC-HTTP Ingestion) and bridges each
stream to the existing **nginx-rtmp**, so packaging (DASH/HLS), recording, `authd` gating,
monetization and the goemon viewer are all unchanged.

```
browser getUserMedia ──WHIP/WebRTC──▶ mediamtx ──ffmpeg/RTMP──▶ nginx-rtmp (salon/<channel>?key=)
                                                                   └▶ DASH/HLS ▶ authd ▶ goemon
```

## How it works

- **WHIP publish URL:** `https://live.georgievski.com/whip/<channelHex>/whip?key=<key>` — `authd`
  proxies `/whip/` to this service (`:8889`), adding CORS (incl. exposing `Location`).
- **Media:** WebRTC/ICE on `bleu:8189/udp`. The pod runs with **hostNetwork** pinned to bleu so
  ICE sees real IPs (no klipper SNAT); `webrtcAdditionalHosts: [192.168.1.53]` is the advertised
  candidate. LAN broadcasters only — a public/TURN setup is needed for internet publishers.
- **Bridge:** `pathDefaults.runOnReady` runs `ffmpeg -i rtsp://localhost:8554/$MTX_PATH
  -c:v copy -c:a aac -f flv rtmp://rtmp.live.svc.cluster.local:1935/salon/$MTX_PATH?$MTX_QUERY`.
  The browser is asked for H.264 so video passes through; audio is transcoded to AAC.
- **Auth (prototype):** none at mediamtx — nginx-rtmp's existing `on_publish` → nagato still
  validates the channel key, so a wrong key never goes live. Credentials come from naruto:
  `GET /api/v1/channels/<enc>/ingest/` (owner-only) returns `{whip_url, channel_id, key}`.

## Deploy

```bash
kubectl apply -f deploy/k3s/mediamtx.yaml    # ns live; ConfigMap + Deployment + Service
```

`mediamtx.yml` in the repo root is the same config, for local runs.

## Client

The goemon **Broadcaster** component (`src/components/Broadcaster.tsx` +
`src/services/WhipPublisher.ts`) is the publisher: `getUserMedia` → `RTCPeerConnection` (H.264
preferred) → WHIP POST → local preview.

## Hardening TODO (this is a prototype)

- Add mediamtx `authHTTPAddress` → a nagato hook so bad publishes are rejected at ingest, not just
  at the RTMP bridge.
- Short-lived publish tokens instead of handing the long-lived channel key to the browser.
- TURN server for broadcasters outside the LAN.
- Move the deploy into doodle (currently a hand-rolled manifest).
# mediamtx
