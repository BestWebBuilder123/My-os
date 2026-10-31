# My OS Remote Browser

A headless Chromium service for the My OS Browser app. It provides authenticated browser sessions, navigation, screenshots and mouse/keyboard input.

## Deploy on Render

1. In Render choose **New → Web Service** and connect `weirdsimplegames/My-os` on branch `main`.
2. Choose **Docker** and set Dockerfile Path to `browser-backend/Dockerfile`.
3. Name the service `myos-browser-backend`.
4. Add `BROWSER_API_KEY` as an environment variable. Use a long random value and keep it private.
5. Deploy. The service health check is `/health`; Render provides an HTTPS `onrender.com` URL.

The service runs Chromium in a container. Sessions are temporary and expire after 15 minutes of inactivity. The browser display is screenshot-based, not a native browser surface. The service requires the API key for all browser actions and limits active sessions.

## Endpoints

- `GET /health`
- `POST /api/sessions`
- `POST /api/sessions/:id/navigate` with `{ "url": "https://example.com" }`
- `GET /api/sessions/:id/screenshot`
- `POST /api/sessions/:id/action` with click/type/key/scroll action data
- `DELETE /api/sessions/:id`

All `/api` requests require the `X-Browser-Key` header.
