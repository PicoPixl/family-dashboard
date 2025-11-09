<img width="2153" height="1313" alt="image" src="https://github.com/user-attachments/assets/15cc289f-61b0-45f5-bbdc-c6855b5f40cf" />

---

# 🏠 Family Dashboard

Beautiful, modern family dashboard for **self-hosting**.
Designed for a home / internal network: shared events, groceries, weather, news, music (Subsonic/Ampache), Nextcloud calendar import, timer, and more.

> **Important security note:** This app is **not secure** for public Internet exposure. Run it only on an internal/trusted network (or behind a properly configured reverse proxy with authentication + TLS / VPN). See **Security** below for mitigation suggestions.

---

## 🚀 Quick Start (recommended: Docker)

The repo includes a `setup.sh` that scaffolds the app and Docker files.

1. Make the script executable and run it:

```bash
bash setup.sh
```

2. Start with Docker Compose:

```bash
cd family-dashboard
docker compose up -d --build
```

3. Open the dashboard in your browser:

```
http://localhost:3927
```

**What this does**

* Frontend served by an nginx container on host port **3927**.
* Backend (Express) listens on port **3001** (exposed to the host by the compose file).
* Persistent data volume: `dashboard-data` contains the JSON data storage.

---

## Manual / Development Run (no Docker)

Requirements: **Node 18+**, npm.

From repo root:

1. Install frontend deps (root `package.json`):

```bash
npm install
npm run build      # produces `dist/`
```

2. Serve the built frontend (use any static server, or `vite preview` for quick dev):

```bash
npm run preview
# OR serve `dist/` with nginx / any static server
```

3. Start the backend:

```bash
cd server
npm install
node server.js     # server listens on 3001 by default
```

4. Visit the frontend (if using `vite preview` it will show port; if using nginx bind it to 3927 as in the Dockerfile/compose).

---

## ✅ Features

* Interactive monthly calendar with event indicators and modal event creation
* Real-time clock (timezone aware)
* Kitchen timer (alarm) — flip from clock view to timer
* Live weather lookup (by ZIP) using open-meteo
* Today’s schedule / agenda
* Grocery list with download/export
* RSS news headlines (configurable RSS feed URL)
* 10 color themes and responsive UI
* Data automatically synced in near-real-time across devices on the same network
* Subsonic / Ampache music playback integration (stream tracks from your server)
* Nextcloud calendar import (public/exportable iCal feed)
* Auto-syncing UI elements and polish features (hover-only delete, synced card heights, etc.)

---

## Configuration & Settings

You can configure everything via the **Settings** UI inside the dashboard. Settings are persisted server-side.

### Default data & where it's stored

The app stores state in a JSON file on the backend:

```
server/data/data.json
```

Default `settings` fields (created automatically if not present):

```json
{
  "zipCode": "10001",
  "timezone": "America/New_York",
  "theme": "purple",
  "familyName": "",
  "timeFormat": "12",
  "showNews": true,
  "newsFeedUrl": "https://feeds.bbci.co.uk/news/rss.xml",
  "musicEnabled": false,
  "musicServer": "",
  "musicUsername": "",
  "musicPassword": "",
  "musicServerType": "subsonic",
  "nextcloudEnabled": false,
  "nextcloudCalendarUrl": ""
}
```

You can:

* Edit these via the Settings UI, OR
* Edit `server/data/data.json` manually (server will recreate defaults if missing). If you edit the file manually, make sure to keep valid JSON and restart server / refresh clients as needed.

---

## Optional integrations & how to use them

### Music: Subsonic / Ampache

* In Settings → Music:

  * Toggle **Music Enabled** = `true`
  * `musicServer` = base URL for your Subsonic/Ampache server (e.g. `http://10.0.1.5:4040`)
  * `musicUsername` / `musicPassword` = credentials
  * `musicServerType` = `subsonic` or `ampache`

**Notes & troubleshooting**

* The frontend attempts to call Subsonic/Ampache endpoints from the browser. This requires that your music server be reachable from clients, and that the music server either allows cross-origin requests (CORS) or that you expose it to the same host/lan where browsers can fetch it directly.
* If streaming returns XML / CORS errors or fails: enable CORS on the music server or host a small proxy that forwards requests (the app does not include a server-side proxy by default).
* The app tries `getRandomSongs` and `stream` REST endpoints (Subsonic). For Ampache, confirm REST equivalents and configuration.

### Nextcloud calendar (iCal export)

* In Settings → Nextcloud:

  * Toggle **Nextcloud Calendar Enabled** = `true`
  * `nextcloudCalendarUrl` = URL of the calendar export (an iCal `.ics` export URL). Many Nextcloud calendar apps provide a public export URL or a shareable URL with `?export`.
* The dashboard will fetch the iCal feed and show events on the calendar.

**Notes**

* If your Nextcloud calendar requires authentication or is behind your LAN, either:

  * Use a calendar share/export link that is publicly accessible (but then it’s public), or
  * Use a CORS proxy that the frontend can use to fetch the feed (the app tries some public CORS-proxy fallbacks, but reliability varies).
* If events aren’t appearing, double-check that the `?export` URL works in a browser (and that it returns a valid iCal).

### RSS News

* Settings → News Feed URL: enter any RSS feed URL.
* The app uses several public CORS proxy fallbacks to fetch RSS. If a feed fails, try a different feed or make the feed accessible from clients.

---

## Ports & URLs

* Backend API: `http://<host>:3001/api`
* Frontend (when using Docker compose provided): `http://localhost:3927`
* Docker maps: backend `3001:3001`, frontend (nginx) `3927:80` inside compose.

Frontend builds determine `API_URL` as:

* If `window.location.hostname === 'localhost'` → `http://localhost:3001/api`
* Otherwise → `http://<your-host>:3001/api` (so ensure the backend is reachable at port 3001 on the host machine).

---

## Data persistence & backups

* Docker Compose volume: `dashboard-data` (contains `server/data/data.json`).
* To backup (example):

```bash
# copy data.json out of running container
docker cp family-dashboard-backend:/app/data/data.json ./backup-data.json
```

* Or access the file from your host if you mounted a host volume instead of a Docker volume.

---

## Troubleshooting

* **Dashboard loads but data is empty**
  Ensure the backend is running on port 3001 and reachable from the browser. Check backend logs: `docker logs family-dashboard-backend`.

* **Music fails / playback is XML / CORS errors**
  Check music server URL, credentials, and CORS. Try opening the Subsonic `getRandomSongs` or `stream` URLs from the browser to see response type.

* **Nextcloud calendar not showing events**
  Confirm the calendar export URL works in a browser and returns `.ics` content. If it requires auth, either use a public export link or set up a proxy.

* **Weather or RSS not loading**
  The app uses public APIs and CORS fallbacks; ensure your network permits outgoing requests. For weather, the app uses **open-meteo** (no API key required).

* **Changes to `data.json` not reflecting**
  The server reads/writes the file; editing it while server is running may be overwritten by the server. Best to edit via UI or stop the server before manual edits.

Check browser console for helpful client-side errors.

---

## Security (Important — read!)

This project **does not implement authentication or hardened access controls**. If you expose it to an untrusted network, anyone who can reach the frontend or the backend API can read/modify your data and trigger actions.

Recommended hardening steps before exposing beyond a secure LAN:

* Keep the app **inside your local network only**.
* Put a reverse proxy (NGINX, Traefik, Caddy) in front of the app and enable:

  * HTTPS (TLS)
  * Basic auth / Single Sign-On (if needed)
  * IP allowlist (if applicable)
* Alternatively, expose the app only over a VPN to trusted clients.
* If you need to expose the music server or Nextcloud publicly, consider the security implications and prefer scoped share tokens or read-only export links.
* Consider adding firewall rules on your host to limit incoming connections.

Example Nginx snippet for basic auth + TLS (conceptual — adapt to your environment):

```nginx
server {
  listen 443 ssl;
  server_name dashboard.example.local;

  ssl_certificate /path/to/fullchain.pem;
  ssl_certificate_key /path/to/privkey.pem;

  auth_basic "Restricted";
  auth_basic_user_file /etc/nginx/.htpasswd;

  location / {
      proxy_pass http://127.0.0.1:3927;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
  }
}
```

---

## Contributing & Development notes

* Frontend: Vite + React; `src/App.jsx` is the main UI.
* Backend: `server/server.js` (Express) — lightweight JSON file storage.
* Styling: Tailwind / CSS (see `src/index.css` and `tailwind.config.js`).

If you want to add a server-side proxy for Subsonic/Nextcloud (to avoid CORS and expose credentials server-side), that is a recommended improvement for security and reliability.

---

## License

MIT License

---

## Changelog / Notes

This README was generated from the packaged app. The app includes:

* Real-time syncing across browsers for events & groceries
* Subsonic/Ampache music support
* RSS with multi-proxy fallback
* Dynamic API URL usage
* 10 theme options and responsive design
* Timer feature (kitchen timer with alarm)

---

Which one would you like next?
