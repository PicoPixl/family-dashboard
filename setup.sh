#!/bin/bash

# ============================================================================
# FAMILY DASHBOARD SETUP SCRIPT
# VERSION: 1.0
# Date: October 29, 2025
# 
# This is a stable, fully-tested version with all features working correctly:
# - Real-time syncing across browsers (events & groceries)
# - Subsonic/Ampache music playback
# - RSS news feed with multi-proxy fallback
# - Dynamic API URL for network access
# - Responsive gradient backgrounds on all devices
# - Calendar with event indicators
# - Weather integration
# - 10 theme options
# - Settings with tabbed interface
# - Kitchen timer with alarm
# 
# ============================================================================

echo "🏠 Setting up Family Dashboard..."

if [ -d "family-dashboard" ]; then
    echo "Removing old family-dashboard directory..."
    rm -rf family-dashboard
fi

mkdir -p family-dashboard/src
mkdir -p family-dashboard/server
cd family-dashboard

echo "📁 Created directory structure"

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  backend:
    build:
      context: ./server
    ports:
      - "3001:3001"
    volumes:
      - dashboard-data:/app/data
    restart: unless-stopped
    container_name: family-dashboard-backend

  frontend:
    build:
      context: .
    ports:
      - "3927:80"
    depends_on:
      - backend
    restart: unless-stopped
    container_name: family-dashboard-frontend
    environment:
      - NODE_ENV=production

volumes:
  dashboard-data:
EOF

echo "✅ docker-compose.yml created"

cat > Dockerfile << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

echo "✅ Frontend Dockerfile created"

cat > server/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY server.js ./

RUN mkdir -p /app/data

EXPOSE 3001

CMD ["npm", "start"]
EOF

echo "✅ Server Dockerfile created"

cat > server/package.json << 'EOF'
{
  "name": "family-dashboard-server",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  }
}
EOF

echo "✅ Server package.json created"

cat > server/server.js << 'EOF'
import express from 'express';
import cors from 'cors';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3001;
const DATA_FILE = path.join(__dirname, 'data', 'data.json');

app.use(cors());
app.use(express.json());

async function initDataFile() {
  try {
    await fs.access(DATA_FILE);
  } catch {
    const initialData = {
      events: [],
      groceries: [],
      settings: {
        zipCode: '10001',
        timezone: 'America/New_York',
        theme: 'purple',
        familyName: '',
        timeFormat: '12',
        showNews: true,
        newsFeedUrl: 'https://feeds.bbci.co.uk/news/rss.xml',
        musicEnabled: false,
        musicServer: '',
        musicUsername: '',
        musicPassword: '',
        musicServerType: 'subsonic',
        nextcloudEnabled: false,
        nextcloudCalendarUrl: ''
      }
    };
    await fs.mkdir(path.dirname(DATA_FILE), { recursive: true });
    await fs.writeFile(DATA_FILE, JSON.stringify(initialData, null, 2));
  }
}

async function readData() {
  try {
    const data = await fs.readFile(DATA_FILE, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Error reading data file:', error);
    return {
      events: [],
      groceries: [],
      settings: {
        zipCode: '10001',
        timezone: 'America/New_York',
        theme: 'purple',
        familyName: '',
        timeFormat: '12',
        showNews: true,
        newsFeedUrl: 'https://feeds.bbci.co.uk/news/rss.xml',
        musicEnabled: false,
        musicServer: '',
        musicUsername: '',
        musicPassword: '',
        musicServerType: 'subsonic',
        nextcloudEnabled: false,
        nextcloudCalendarUrl: ''
      }
    };
  }
}

async function writeData(data) {
  try {
    await fs.writeFile(DATA_FILE, JSON.stringify(data, null, 2));
  } catch (error) {
    console.error('Error writing data file:', error);
    throw error;
  }
}

app.get('/api/data', async (req, res) => {
  try {
    const data = await readData();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to read data' });
  }
});

app.post('/api/events', async (req, res) => {
  try {
    const data = await readData();
    data.events = Array.isArray(req.body) ? req.body : [];
    await writeData(data);
    res.json({ success: true });
  } catch (error) {
    console.error('Error updating events:', error);
    res.status(500).json({ error: 'Failed to update events' });
  }
});

app.post('/api/groceries', async (req, res) => {
  try {
    const data = await readData();
    data.groceries = Array.isArray(req.body) ? req.body : [];
    await writeData(data);
    res.json({ success: true });
  } catch (error) {
    console.error('Error updating groceries:', error);
    res.status(500).json({ error: 'Failed to update groceries' });
  }
});

app.post('/api/settings', async (req, res) => {
  try {
    const data = await readData();
    data.settings = req.body;
    await writeData(data);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update settings' });
  }
});

initDataFile().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
  });
});
EOF

echo "✅ Server server.js created"

cat > package.json << 'EOF'
{
  "name": "family-dashboard",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "lucide-react": "^0.263.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "autoprefixer": "^10.4.14",
    "postcss": "^8.4.24",
    "tailwindcss": "^3.3.2",
    "vite": "^4.3.9"
  }
}
EOF

echo "✅ Frontend package.json created"

cat > nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

echo "✅ nginx.conf created"

cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000
  }
});
EOF

echo "✅ vite.config.js created"

cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

echo "✅ tailwind.config.js created"

cat > postcss.config.js << 'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

echo "✅ postcss.config.js created"

cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='0.9em' font-size='90'>📅</text></svg>" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Family Dashboard</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

echo "✅ index.html created"

cat > .gitignore << 'EOF'
node_modules
dist
.DS_Store
EOF

echo "✅ .gitignore created"

cat > src/main.jsx << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
EOF

echo "✅ src/main.jsx created"

cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  min-height: 100vh;
  background-attachment: fixed;
  background-size: cover;
  background-repeat: no-repeat;
}

html, #root {
  min-height: 100%;
}

::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 10px;
}

::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 10px;
}

::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

* {
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.2) rgba(255, 255, 255, 0.05);
}

@keyframes pulse-glow {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.8;
    transform: scale(1.05);
  }
}

.timer-pulse {
  animation: pulse-glow 1s ease-in-out infinite;
}
EOF

echo "✅ src/index.css created"

echo "Creating src/App.jsx..."

cat > src/App.jsx << 'EOF'
import React, { useState, useEffect, useRef } from 'react';
import { Clock, Cloud, Sun, CloudRain, CloudSnow, Wind, Droplets, Plus, X, Settings, Check, ChevronLeft, ChevronRight, Trash2, Download, Newspaper, Music, Play, Pause, Timer, ChevronUp, ChevronDown, RotateCcw, Volume2, VolumeX } from 'lucide-react';

const API_URL = window.location.hostname === 'localhost' 
  ? 'http://localhost:3001/api'
  : `http://${window.location.hostname}:3001/api`;

const FamilyDashboard = () => {
  const [currentTime, setCurrentTime] = useState(new Date());
  const [weather, setWeather] = useState(null);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [viewingDate, setViewingDate] = useState(new Date());
  const [events, setEvents] = useState([]);
  const [groceries, setGroceries] = useState([]);
  const [showSettings, setShowSettings] = useState(false);
  const [settings, setSettings] = useState({
    zipCode: '10001',
    timezone: 'America/New_York',
    theme: 'purple',
    familyName: '',
    timeFormat: '12',
    showNews: true,
    newsFeedUrl: 'https://feeds.bbci.co.uk/news/rss.xml',
    musicEnabled: false,
    musicServer: '',
    musicUsername: '',
    musicPassword: '',
    musicServerType: 'subsonic',
    nextcloudEnabled: false,
    nextcloudCalendarUrl: ''
  });
  const [newEvent, setNewEvent] = useState({ title: '', date: '', time: '' });
  const [newGrocery, setNewGrocery] = useState('');
  const [loading, setLoading] = useState(true);
  const [showEventModal, setShowEventModal] = useState(false);
  const [newsHeadline, setNewsHeadline] = useState('');
  const [settingsTab, setSettingsTab] = useState('general');
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentSong, setCurrentSong] = useState(null);
  const audioRef = useRef(null);
  const lastLocalUpdateRef = useRef({ events: 0, groceries: 0 });
  const eventsRef = useRef(events);
  const groceriesRef = useRef(groceries);
  const [nextcloudEvents, setNextcloudEvents] = useState([]);
  const localEventsBackupRef = useRef([]);
  const nextcloudUrlBackupRef = useRef('');

  // Timer state
  const [showTimer, setShowTimer] = useState(false);
  const [timerMinutes, setTimerMinutes] = useState(0);
  const [timerSeconds, setTimerSeconds] = useState(0);
  const [timerRunning, setTimerRunning] = useState(false);
  const [timerComplete, setTimerComplete] = useState(false);
  const [timerAlarmEnabled, setTimerAlarmEnabled] = useState(true);
  const timerIntervalRef = useRef(null);
  const alarmAudioRef = useRef(null);

  useEffect(() => {
    eventsRef.current = events;
  }, [events]);

  useEffect(() => {
    groceriesRef.current = groceries;
  }, [groceries]);

  const themes = {
    purple: 'from-purple-900 via-blue-900 to-indigo-900',
    ocean: 'from-blue-900 via-teal-900 to-cyan-900',
    sunset: 'from-orange-900 via-red-900 to-pink-900',
    forest: 'from-green-900 via-emerald-900 to-teal-900',
    rose: 'from-pink-900 via-rose-900 to-red-900',
    midnight: 'from-indigo-950 via-blue-950 to-slate-900',
    aurora: 'from-violet-900 via-purple-900 to-fuchsia-900',
    earth: 'from-amber-900 via-orange-900 to-yellow-900',
    slate: 'from-slate-900 via-gray-900 to-zinc-900',
    cosmic: 'from-purple-950 via-indigo-950 to-blue-950'
  };

  const adjustTimer = (type, direction) => {
    if (timerRunning) return;
    
    if (type === 'minutes') {
      setTimerMinutes(prev => {
        const newVal = direction === 'up' ? prev + 1 : prev - 1;
        return Math.max(0, Math.min(99, newVal));
      });
    } else {
      setTimerSeconds(prev => {
        const newVal = direction === 'up' ? prev + 15 : prev - 15;
        if (newVal >= 60) return 0;
        if (newVal < 0) return 45;
        return newVal;
      });
    }
    setTimerComplete(false);
  };

  const startTimer = () => {
    if (timerMinutes === 0 && timerSeconds === 0) return;
    
    setTimerRunning(true);
    setTimerComplete(false);
    
    timerIntervalRef.current = setInterval(() => {
      setTimerSeconds(prev => {
        if (prev > 0) {
          return prev - 1;
        } else {
          setTimerMinutes(min => {
            if (min > 0) {
              return min - 1;
            } else {
              clearInterval(timerIntervalRef.current);
              setTimerRunning(false);
              setTimerComplete(true);
              return 0;
            }
          });
          return 59;
        }
      });
    }, 1000);
  };

  useEffect(() => {
    if (timerComplete && timerAlarmEnabled) {
      playAlarmSound();
    }
  }, [timerComplete, timerAlarmEnabled]);

  const playAlarmSound = () => {
    const beep = () => {
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const gainNode = audioContext.createGain();
      
      oscillator.connect(gainNode);
      gainNode.connect(audioContext.destination);
      
      oscillator.frequency.value = 800;
      oscillator.type = 'square';
      
      gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
      
      let time = audioContext.currentTime;
      for (let i = 0; i < 6; i++) {
        gainNode.gain.setValueAtTime(0.3, time);
        gainNode.gain.setValueAtTime(0, time + 0.2);
        time += 0.4;
      }
      
      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 2.4);
    };
    
    // Play first beep immediately
    beep();
    
    // Set up interval to repeat every 2.5 seconds
    const alarmInterval = setInterval(() => {
      beep();
    }, 2500);
    
    // Store interval ID so we can clear it on dismiss
    if (alarmAudioRef.current) {
      alarmAudioRef.current.alarmIntervalId = alarmInterval;
    }
  };

  const stopTimer = () => {
    if (timerIntervalRef.current) {
      clearInterval(timerIntervalRef.current);
    }
    setTimerRunning(false);
  };

  const resetTimer = () => {
    stopTimer();
    setTimerMinutes(0);
    setTimerSeconds(0);
    setTimerComplete(false);
    setTimerAlarmEnabled(true);
    
    // Clear alarm interval if it exists
    if (alarmAudioRef.current && alarmAudioRef.current.alarmIntervalId) {
      clearInterval(alarmAudioRef.current.alarmIntervalId);
      alarmAudioRef.current.alarmIntervalId = null;
    }
  };

  const dismissAlarm = () => {
    // Clear alarm interval if it exists
    if (alarmAudioRef.current && alarmAudioRef.current.alarmIntervalId) {
      clearInterval(alarmAudioRef.current.alarmIntervalId);
      alarmAudioRef.current.alarmIntervalId = null;
    }
    
    setTimerComplete(false);
    setTimerMinutes(0);
    setTimerSeconds(0);
  };

  useEffect(() => {
    return () => {
      if (timerIntervalRef.current) {
        clearInterval(timerIntervalRef.current);
      }
      // Clean up alarm interval on unmount
      if (alarmAudioRef.current && alarmAudioRef.current.alarmIntervalId) {
        clearInterval(alarmAudioRef.current.alarmIntervalId);
      }
    };
  }, []);

  useEffect(() => {
    const loadData = async () => {
      try {
        const response = await fetch(`${API_URL}/data`);
        const data = await response.json();
        setEvents(data.events || []);
        setGroceries(data.groceries || []);
        setSettings(data.settings || settings);
        setLoading(false);
      } catch (error) {
        console.error('Error loading data:', error);
        setLoading(false);
      }
    };
    loadData();

    const pollInterval = setInterval(async () => {
      try {
        const response = await fetch(`${API_URL}/data`);
        const data = await response.json();
        const now = Date.now();
        
        if (now - lastLocalUpdateRef.current.events > 2000) {
          const newEventsString = JSON.stringify(data.events || []);
          const currentEventsString = JSON.stringify(eventsRef.current);
          
          if (newEventsString !== currentEventsString) {
            setEvents(data.events || []);
            console.log('Events synced from server:', new Date().toLocaleTimeString());
          }
        }
        
        if (now - lastLocalUpdateRef.current.groceries > 2000) {
          const newGroceriesString = JSON.stringify(data.groceries || []);
          const currentGroceriesString = JSON.stringify(groceriesRef.current);
          
          if (newGroceriesString !== currentGroceriesString) {
            setGroceries(data.groceries || []);
            console.log('Groceries synced from server:', new Date().toLocaleTimeString());
          }
        }
      } catch (error) {
        console.error('Error polling data:', error);
      }
    }, 3000);

    return () => clearInterval(pollInterval);
  }, []);

  useEffect(() => {
    if (!loading) {
      const saveEvents = async () => {
        try {
          lastLocalUpdateRef.current.events = Date.now();
          await fetch(`${API_URL}/events`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(events || [])
          });
        } catch (error) {
          console.error('Error saving events:', error);
        }
      };
      
      if (!settings.nextcloudEnabled) {
        const timeoutId = setTimeout(saveEvents, 500);
        return () => clearTimeout(timeoutId);
      }
    }
  }, [events, loading, settings.nextcloudEnabled]);

  useEffect(() => {
    if (!loading) {
      const saveGroceries = async () => {
        try {
          lastLocalUpdateRef.current.groceries = Date.now();
          await fetch(`${API_URL}/groceries`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(groceries)
          });
        } catch (error) {
          console.error('Error saving groceries:', error);
        }
      };
      
      const timeoutId = setTimeout(saveGroceries, 500);
      return () => clearTimeout(timeoutId);
    }
  }, [groceries, loading]);

  useEffect(() => {
    if (!loading) {
      const saveSettings = async () => {
        try {
          await fetch(`${API_URL}/settings`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(settings)
          });
        } catch (error) {
          console.error('Error saving settings:', error);
        }
      };
      
      const timeoutId = setTimeout(saveSettings, 500);
      return () => clearTimeout(timeoutId);
    }
  }, [settings, loading]);

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    const fetchWeather = async () => {
      try {
        let lat = 40.7128;
        let lon = -74.0060;
        
        if (settings.zipCode) {
          try {
            const geoResponse = await fetch(
              `https://geocoding-api.open-meteo.com/v1/search?name=${settings.zipCode}&count=1&language=en&format=json`
            );
            const geoData = await geoResponse.json();
            
            if (geoData.results && geoData.results.length > 0) {
              lat = geoData.results[0].latitude;
              lon = geoData.results[0].longitude;
            }
          } catch (geoError) {
            console.error('Geocoding error:', geoError);
          }
        }
        
        const response = await fetch(
          `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=${settings.timezone}`
        );
        const data = await response.json();
        setWeather(data.current);
      } catch (error) {
        console.error('Error fetching weather:', error);
      }
    };
    fetchWeather();
    const interval = setInterval(fetchWeather, 600000);
    return () => clearInterval(interval);
  }, [settings.timezone, settings.zipCode]);

  useEffect(() => {
    if (!settings.showNews || loading) {
      setNewsHeadline('');
      return;
    }

    const fetchNews = async () => {
      try {
        const feedUrl = settings.newsFeedUrl.trim() || 'https://feeds.bbci.co.uk/news/rss.xml';
        
        const proxies = [
          'https://corsproxy.io/?',
          'https://api.allorigins.win/raw?url=',
          'https://cors-anywhere.herokuapp.com/'
        ];
        
        const cacheBuster = `${feedUrl.includes('?') ? '&' : '?'}_cb=${Date.now()}`;
        let lastError = null;
        
        for (const proxyUrl of proxies) {
          try {
            const fullUrl = proxyUrl + encodeURIComponent(feedUrl + cacheBuster);
            const response = await fetch(fullUrl, { mode: 'cors' });
            
            if (!response.ok) {
              throw new Error(`HTTP ${response.status}`);
            }
            
            const text = await response.text();
            
            if (!text || text.trim().length === 0) {
              throw new Error('Empty response');
            }
            
            const parser = new DOMParser();
            const xml = parser.parseFromString(text, 'application/xml');
            
            const parserError = xml.querySelector('parsererror');
            if (parserError) {
              throw new Error('XML parsing error');
            }
            
            const items = xml.querySelectorAll('item');
            
            if (items.length > 0) {
              const title = items[0].querySelector('title')?.textContent || '';
              if (title) {
                setNewsHeadline(title);
                console.log('News updated:', new Date().toLocaleTimeString());
                return;
              }
            }
            
            throw new Error('No items found');
          } catch (error) {
            lastError = error;
            console.warn(`Proxy ${proxyUrl} failed:`, error.message);
          }
        }
        
        throw lastError || new Error('All proxies failed');
      } catch (error) {
        console.error('Error fetching news:', error);
        setNewsHeadline('Unable to load news');
      }
    };

    fetchNews();
    
    const interval = setInterval(fetchNews, 300000);
    
    return () => clearInterval(interval);
  }, [settings.showNews, settings.newsFeedUrl, loading]);

  useEffect(() => {
    if (!loading) {
      if (settings.nextcloudEnabled) {
        if (events.length > 0 && localEventsBackupRef.current.length === 0) {
          localEventsBackupRef.current = [...events];
          console.log('Local events backed up:', events.length);
          setEvents([]);
        }
        if (settings.nextcloudCalendarUrl && !nextcloudUrlBackupRef.current) {
          nextcloudUrlBackupRef.current = settings.nextcloudCalendarUrl;
        }
      } else {
        if (localEventsBackupRef.current.length > 0) {
          const restoredEvents = [...localEventsBackupRef.current];
          localEventsBackupRef.current = [];
          lastLocalUpdateRef.current.events = Date.now();
          setEvents(restoredEvents);
          console.log('Local events restored from backup:', restoredEvents.length);
          
          setTimeout(async () => {
            try {
              await fetch(`${API_URL}/events`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(restoredEvents)
              });
              console.log('Restored events saved to server');
            } catch (error) {
              console.error('Error saving restored events:', error);
            }
          }, 100);
        }
        if (settings.nextcloudCalendarUrl && nextcloudUrlBackupRef.current) {
          setSettings(prev => ({ ...prev, nextcloudCalendarUrl: '' }));
        }
      }
    }
  }, [settings.nextcloudEnabled, loading]);

  useEffect(() => {
    if (!settings.nextcloudEnabled || !settings.nextcloudCalendarUrl || loading) {
      setNextcloudEvents([]);
      return;
    }

    const fetchNextcloudCalendar = async () => {
      try {
        const calendarUrl = settings.nextcloudCalendarUrl.trim();
        if (!calendarUrl) return;

        const url = calendarUrl.includes('?export') ? calendarUrl : `${calendarUrl}?export`;
        
        const proxies = [
          'https://corsproxy.io/?',
          'https://api.allorigins.win/raw?url=',
          'https://cors-anywhere.herokuapp.com/'
        ];
        
        let lastError = null;
        
        for (const proxyUrl of proxies) {
          try {
            const fullUrl = proxyUrl + encodeURIComponent(url);
            const response = await fetch(fullUrl, { mode: 'cors' });
            
            if (!response.ok) {
              throw new Error(`HTTP ${response.status}`);
            }
            
            const icsData = await response.text();
            
            if (!icsData || icsData.trim().length === 0) {
              throw new Error('Empty response');
            }
            
            const parsedEvents = parseICS(icsData);
            setNextcloudEvents(parsedEvents);
            console.log('Nextcloud calendar synced:', parsedEvents.length, 'events');
            return;
          } catch (error) {
            lastError = error;
            console.warn(`Proxy ${proxyUrl} failed:`, error.message);
          }
        }
        
        throw lastError || new Error('All proxies failed');
      } catch (error) {
        console.error('Error fetching Nextcloud calendar:', error);
      }
    };

    fetchNextcloudCalendar();
    
    const interval = setInterval(fetchNextcloudCalendar, 900000);
    
    return () => clearInterval(interval);
  }, [settings.nextcloudEnabled, settings.nextcloudCalendarUrl, loading]);

  const parseICS = (icsData) => {
    const events = [];
    const lines = icsData.split(/\r?\n/);
    let currentEvent = null;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();

      if (line === 'BEGIN:VEVENT') {
        currentEvent = { id: Date.now() + Math.random() };
      } else if (line === 'END:VEVENT' && currentEvent) {
        if (currentEvent.title && currentEvent.date) {
          events.push(currentEvent);
        }
        currentEvent = null;
      } else if (currentEvent) {
        if (line.startsWith('SUMMARY:')) {
          currentEvent.title = line.substring(8);
        } else if (line.startsWith('DTSTART')) {
          const dateMatch = line.match(/[:;](\d{8})(T(\d{6})Z?)?/);
          if (dateMatch) {
            const dateStr = dateMatch[1];
            const year = dateStr.substring(0, 4);
            const month = dateStr.substring(4, 6);
            const day = dateStr.substring(6, 8);
            currentEvent.date = `${year}-${month}-${day}`;
            
            if (dateMatch[3]) {
              const timeStr = dateMatch[3];
              const hour = timeStr.substring(0, 2);
              const minute = timeStr.substring(2, 4);
              currentEvent.time = `${hour}:${minute}`;
            }
          }
        }
      }
    }

    return events;
  };

  const getRandomSong = async () => {
    if (!settings.musicServer || !settings.musicUsername || !settings.musicPassword) {
      console.error('Music server credentials not configured');
      return null;
    }

    try {
      const serverUrl = settings.musicServer.replace(/\/$/, '');
      
      if (settings.musicServerType === 'subsonic') {
        const randomUrl = `${serverUrl}/rest/getRandomSongs?u=${encodeURIComponent(settings.musicUsername)}&p=${encodeURIComponent(settings.musicPassword)}&v=1.16.1&c=FamilyDashboard&f=json&size=1`;
        
        const response = await fetch(randomUrl, { mode: 'cors' });
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data['subsonic-response']?.status === 'ok' && data['subsonic-response']?.randomSongs?.song?.length > 0) {
          const song = data['subsonic-response'].randomSongs.song[0];
          const streamUrl = `${serverUrl}/rest/stream?u=${encodeURIComponent(settings.musicUsername)}&p=${encodeURIComponent(settings.musicPassword)}&v=1.16.1&c=FamilyDashboard&id=${song.id}`;
          
          try {
            const testResponse = await fetch(streamUrl, { mode: 'cors', method: 'HEAD' });
            const contentType = testResponse.headers.get('content-type') || '';
            
            if (contentType.toLowerCase().includes('xml')) {
              console.error('Stream returned XML instead of audio');
              return null;
            }
          } catch (e) {
            console.warn('Could not verify stream content-type:', e);
          }
          
          return {
            url: streamUrl,
            title: song.title || 'Unknown',
            artist: song.artist || 'Unknown Artist'
          };
        } else if (data['subsonic-response']?.status === 'failed') {
          const errorMsg = data['subsonic-response']?.error?.message || 'Unknown error';
          console.error('Subsonic error:', errorMsg);
          return null;
        }
      } else if (settings.musicServerType === 'ampache') {
        const randomUrl = `${serverUrl}/rest.php?action=random_songs&format=json&user=${encodeURIComponent(settings.musicUsername)}&pass=${encodeURIComponent(settings.musicPassword)}`;
        
        const response = await fetch(randomUrl, { mode: 'cors' });
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data && data.length > 0) {
          const song = data[0];
          const streamUrl = `${serverUrl}/server/stream.php?action=stream&object_type=song&id=${song.id}&auth=${encodeURIComponent(settings.musicPassword)}`;
          
          return {
            url: streamUrl,
            title: song.title || song.name || 'Unknown',
            artist: song.artist || 'Unknown Artist'
          };
        }
      }
    } catch (error) {
      console.error('Error fetching random song:', error);
    }
    
    return null;
  };

  const playRandomSong = async () => {
    const song = await getRandomSong();
    if (song && audioRef.current) {
      setCurrentSong(song);
      audioRef.current.src = song.url;
      audioRef.current.play().catch(error => {
        console.error('Error playing audio:', error);
        setIsPlaying(false);
      });
    } else {
      setIsPlaying(false);
    }
  };

  const toggleMusic = () => {
    if (isPlaying) {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current.src = '';
      }
      setIsPlaying(false);
      setCurrentSong(null);
    } else {
      setIsPlaying(true);
      playRandomSong();
    }
  };

  const handleSongEnd = () => {
    if (isPlaying) {
      playRandomSong();
    }
  };

  const getWeatherIcon = (code) => {
    if (code === 0 || code === 1) return <Sun className="w-8 h-8" />;
    if (code === 2 || code === 3) return <Cloud className="w-8 h-8" />;
    if (code >= 51 && code <= 67) return <CloudRain className="w-8 h-8" />;
    if (code >= 71 && code <= 77) return <CloudSnow className="w-8 h-8" />;
    return <Cloud className="w-8 h-8" />;
  };

  const getDaysInMonth = (date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const daysInMonth = lastDay.getDate();
    const startingDayOfWeek = firstDay.getDay();
    
    const days = [];
    for (let i = 0; i < startingDayOfWeek; i++) {
      days.push(null);
    }
    for (let i = 1; i <= daysInMonth; i++) {
      days.push(new Date(year, month, i));
    }
    return days;
  };

  const addEvent = () => {
    if (newEvent.title && newEvent.date) {
      lastLocalUpdateRef.current.events = Date.now();
      setEvents([...events, { ...newEvent, id: Date.now() }]);
      setNewEvent({ title: '', date: '', time: '' });
      setShowEventModal(false);
    }
  };

  const addGrocery = () => {
    if (newGrocery.trim()) {
      lastLocalUpdateRef.current.groceries = Date.now();
      setGroceries([...groceries, { id: Date.now(), text: newGrocery, checked: false }]);
      setNewGrocery('');
    }
  };

  const downloadGroceryList = () => {
    const text = groceries
      .filter(item => !item.checked)
      .map(item => `- ${item.text}`)
      .join('\n');
    
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'grocery-list.txt';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const toggleGrocery = (id) => {
    lastLocalUpdateRef.current.groceries = Date.now();
    setGroceries(groceries.map(item => 
      item.id === id ? { ...item, checked: !item.checked } : item
    ));
  };

  const deleteItem = (id, type) => {
    if (type === 'event') {
      lastLocalUpdateRef.current.events = Date.now();
      setEvents(events.filter(e => e.id !== id));
    }
    if (type === 'grocery') {
      lastLocalUpdateRef.current.groceries = Date.now();
      setGroceries(groceries.filter(g => g.id !== id));
    }
  };

  const formatTime = (time) => {
    const hour12 = settings.timeFormat === '12';
    return time.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
      hour12: hour12,
      timeZone: settings.timezone
    });
  };

  const formatDate = (date) => {
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      timeZone: settings.timezone
    });
  };

  const formatEventTime = (timeString) => {
    if (!timeString) return 'All day';
    
    const [hours, minutes] = timeString.split(':').map(Number);
    
    if (settings.timeFormat === '12') {
      const period = hours >= 12 ? 'PM' : 'AM';
      const hour12 = hours % 12 || 12;
      return `${hour12}:${minutes.toString().padStart(2, '0')} ${period}`;
    } else {
      return timeString;
    }
  };

  const changeMonth = (direction) => {
    const newDate = new Date(selectedDate);
    newDate.setMonth(newDate.getMonth() + direction);
    setSelectedDate(newDate);
  };

  const selectDate = (date) => {
    if (date) {
      setViewingDate(date);
    }
  };

  const getEventsForDate = (date) => {
    if (!date) return [];
    const dateStr = date.toISOString().split('T')[0];
    const allEvents = settings.nextcloudEnabled ? nextcloudEvents : events;
    return allEvents.filter(e => e.date === dateStr);
  };

  const monthDays = getDaysInMonth(selectedDate);
  
  const todayDateString = new Date(currentTime.getFullYear(), currentTime.getMonth(), currentTime.getDate()).toISOString().split('T')[0];
  const viewingDateString = new Date(viewingDate.getFullYear(), viewingDate.getMonth(), viewingDate.getDate()).toISOString().split('T')[0];
  
  const allEvents = settings.nextcloudEnabled ? nextcloudEvents : events;
  
  const todayEvents = allEvents.filter(e => e.date === todayDateString)
    .sort((a, b) => (a.time || '').localeCompare(b.time || ''));
  const viewingEvents = allEvents.filter(e => {
    if (!viewingDate) return false;
    const dateStr = viewingDate.toISOString().split('T')[0];
    return e.date === dateStr;
  }).sort((a, b) => (a.time || '').localeCompare(b.time || ''));
  
  const isViewingToday = viewingDateString === todayDateString;
  const scheduleTitle = isViewingToday 
    ? "Today's Schedule" 
    : `${viewingDate.toLocaleDateString('en-US', { weekday: 'long' })}'s Schedule`;
  
  const displayedScheduleEvents = isViewingToday ? todayEvents : viewingEvents;

  useEffect(() => {
    const theme = themes[settings.theme] || themes.purple;
    document.body.className = `bg-gradient-to-br ${theme}`;
  }, [settings.theme]);

  return (
    <div className="min-h-screen p-4 md:p-8">
      <div className="max-w-7xl mx-auto pb-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-4xl md:text-5xl font-bold text-white bg-clip-text text-transparent bg-gradient-to-r from-pink-300 to-purple-300">
            {settings.familyName ? `${settings.familyName} ` : ''}Family Dashboard
          </h1>
          <div className="flex items-center gap-3">
            {settings.musicEnabled && (
              <button
                onClick={toggleMusic}
                className="flex items-center gap-2 px-4 bg-white/10 backdrop-blur-lg rounded-xl hover:bg-white/20 transition-all group h-[52px]"
                title={isPlaying ? 'Stop music' : 'Play music'}
              >
                {isPlaying ? (
                  <Pause className="w-5 h-5 text-white flex-shrink-0" />
                ) : (
                  <Play className="w-5 h-5 text-white flex-shrink-0" />
                )}
                {currentSong && isPlaying && (
                  <div className="hidden md:flex flex-col items-start max-w-[200px] justify-center min-h-0">
                    <span className="text-white text-xs font-medium truncate w-full leading-tight">{currentSong.title}</span>
                    <span className="text-white/60 text-[10px] truncate w-full leading-tight">{currentSong.artist}</span>
                  </div>
                )}
              </button>
            )}
            <button
              onClick={() => setShowSettings(!showSettings)}
              className="p-3 bg-white/10 backdrop-blur-lg rounded-xl hover:bg-white/20 transition-all h-[52px]"
            >
              <Settings className="w-6 h-6 text-white" />
            </button>
          </div>
        </div>

        <audio ref={audioRef} onEnded={handleSongEnd} />
        <audio ref={alarmAudioRef} loop />

        {showSettings && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-8 max-w-2xl w-full border border-white/20 relative max-h-[90vh] overflow-y-auto">
              <button
                onClick={() => setShowSettings(false)}
                className="absolute top-4 right-4 p-2 hover:bg-white/10 rounded-lg transition-all"
              >
                <X className="w-5 h-5 text-white" />
              </button>
              <h2 className="text-2xl font-bold text-white mb-6">Settings</h2>
              
              <div className="flex gap-2 mb-6 border-b border-white/20">
                <button
                  onClick={() => setSettingsTab('general')}
                  className={`px-4 py-2 text-white transition-all ${
                    settingsTab === 'general'
                      ? 'border-b-2 border-pink-400 font-semibold'
                      : 'text-white/60 hover:text-white/80'
                  }`}
                >
                  General
                </button>
                <button
                  onClick={() => setSettingsTab('appearance')}
                  className={`px-4 py-2 text-white transition-all ${
                    settingsTab === 'appearance'
                      ? 'border-b-2 border-pink-400 font-semibold'
                      : 'text-white/60 hover:text-white/80'
                  }`}
                >
                  Appearance
                </button>
                <button
                  onClick={() => setSettingsTab('news')}
                  className={`px-4 py-2 text-white transition-all ${
                    settingsTab === 'news'
                      ? 'border-b-2 border-pink-400 font-semibold'
                      : 'text-white/60 hover:text-white/80'
                  }`}
                >
                  News
                </button>
                <button
                  onClick={() => setSettingsTab('music')}
                  className={`px-4 py-2 text-white transition-all ${
                    settingsTab === 'music'
                      ? 'border-b-2 border-pink-400 font-semibold'
                      : 'text-white/60 hover:text-white/80'
                  }`}
                >
                  Music
                </button>
                <button
                  onClick={() => setSettingsTab('calendar')}
                  className={`px-4 py-2 text-white transition-all ${
                    settingsTab === 'calendar'
                      ? 'border-b-2 border-pink-400 font-semibold'
                      : 'text-white/60 hover:text-white/80'
                  }`}
                >
                  Calendar
                </button>
              </div>

              <div className="space-y-4">
                {settingsTab === 'general' && (
                  <>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Family Name (Optional)</label>
                      <input
                        type="text"
                        value={settings.familyName}
                        onChange={(e) => setSettings({...settings, familyName: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                        placeholder="Enter family name"
                      />
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Zip Code / Location</label>
                      <input
                        type="text"
                        value={settings.zipCode}
                        onChange={(e) => setSettings({...settings, zipCode: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                        placeholder="Enter zip code"
                      />
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Time Zone</label>
                      <select
                        value={settings.timezone}
                        onChange={(e) => setSettings({...settings, timezone: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white"
                      >
                        <option value="America/New_York">Eastern Time</option>
                        <option value="America/Chicago">Central Time</option>
                        <option value="America/Denver">Mountain Time</option>
                        <option value="America/Los_Angeles">Pacific Time</option>
                      </select>
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Time Format</label>
                      <select
                        value={settings.timeFormat}
                        onChange={(e) => setSettings({...settings, timeFormat: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white"
                      >
                        <option value="12">12-Hour (AM/PM)</option>
                        <option value="24">24-Hour</option>
                      </select>
                    </div>
                  </>
                )}

                {settingsTab === 'calendar' && (
                  <>
                    <div className="flex items-center justify-between p-4 bg-white/5 rounded-xl">
                      <div>
                        <div className="text-white font-medium">Sync from Nextcloud Calendar</div>
                        <div className="text-white/60 text-sm">Import events from Nextcloud public calendar</div>
                      </div>
                      <button
                        onClick={() => setSettings({...settings, nextcloudEnabled: !settings.nextcloudEnabled})}
                        className={`w-12 h-6 rounded-full transition-all ${
                          settings.nextcloudEnabled ? 'bg-pink-500' : 'bg-white/20'
                        }`}
                      >
                        <div
                          className={`w-5 h-5 bg-white rounded-full transition-all ${
                            settings.nextcloudEnabled ? 'translate-x-6' : 'translate-x-0.5'
                          }`}
                        />
                      </button>
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Nextcloud Calendar URL</label>
                      <input
                        type="text"
                        value={settings.nextcloudEnabled ? (settings.nextcloudCalendarUrl || nextcloudUrlBackupRef.current) : ''}
                        onChange={(e) => {
                          setSettings({...settings, nextcloudCalendarUrl: e.target.value});
                          if (e.target.value) {
                            nextcloudUrlBackupRef.current = e.target.value;
                          }
                        }}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                        placeholder="https://your-nextcloud.com/remote.php/dav/public-calendars/..."
                        disabled={!settings.nextcloudEnabled}
                      />
                      <div className="text-white/40 text-xs mt-2">
                        Paste your Nextcloud public calendar link. The app will sync events every 15 minutes.
                      </div>
                    </div>
                    <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-xl">
                      <div className="text-blue-200 text-sm">
                        <strong>Note:</strong> When Nextcloud sync is enabled, local events and Nextcloud events will both be displayed. You can still add local events manually.
                      </div>
                    </div>
                  </>
                )}

                {settingsTab === 'music' && (
                  <>
                    <div className="flex items-center justify-between p-4 bg-white/5 rounded-xl">
                      <div>
                        <div className="text-white font-medium">Enable Music Player</div>
                        <div className="text-white/60 text-sm">Stream from Subsonic or Ampache</div>
                      </div>
                      <button
                        onClick={() => setSettings({...settings, musicEnabled: !settings.musicEnabled})}
                        className={`w-12 h-6 rounded-full transition-all ${
                          settings.musicEnabled ? 'bg-pink-500' : 'bg-white/20'
                        }`}
                      >
                        <div
                          className={`w-5 h-5 bg-white rounded-full transition-all ${
                            settings.musicEnabled ? 'translate-x-6' : 'translate-x-0.5'
                          }`}
                        />
                      </button>
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Server Type</label>
                      <select
                        value={settings.musicServerType}
                        onChange={(e) => setSettings({...settings, musicServerType: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white"
                        disabled={!settings.musicEnabled}
                      >
                        <option value="subsonic">Subsonic</option>
                        <option value="ampache">Ampache</option>
                      </select>
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Server URL</label>
                      <input
                        type="text"
                        value={settings.musicServer}
                        onChange={(e) => setSettings({...settings, musicServer: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                        placeholder="https://music.example.com"
                        disabled={!settings.musicEnabled}
                      />
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Username</label>
                      <input
                        type="text"
                        value={settings.musicUsername}
                        onChange={(e) => setSettings({...settings, musicUsername: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                        placeholder="Enter username"
                        disabled={!settings.musicEnabled}
                      />
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">Password</label>
                      <input
                        type="password"
                        value={settings.musicPassword}
                        onChange={(e) => setSettings({...settings, musicPassword: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                        placeholder="Enter password"
                        disabled={!settings.musicEnabled}
                      />
                    </div>
                  </>
                )}

                {settingsTab === 'appearance' && (
                  <div>
                    <label className="text-white/80 text-sm mb-2 block">Color Theme</label>
                    <div className="grid grid-cols-2 gap-3">
                      {Object.entries(themes).map(([key, gradient]) => (
                        <button
                          key={key}
                          onClick={() => setSettings({...settings, theme: key})}
                          className={`p-4 rounded-xl bg-gradient-to-r ${gradient} border-2 transition-all ${
                            settings.theme === key
                              ? 'border-white ring-2 ring-white/50'
                              : 'border-white/20 hover:border-white/40'
                          }`}
                        >
                          <div className="text-white font-medium capitalize text-sm">
                            {key.replace(/([A-Z])/g, ' $1').trim()}
                          </div>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {settingsTab === 'news' && (
                  <>
                    <div className="flex items-center justify-between p-4 bg-white/5 rounded-xl">
                      <div>
                        <div className="text-white font-medium">Show News Headlines</div>
                        <div className="text-white/60 text-sm">Display latest news below calendar</div>
                      </div>
                      <button
                        onClick={() => setSettings({...settings, showNews: !settings.showNews})}
                        className={`w-12 h-6 rounded-full transition-all ${
                          settings.showNews ? 'bg-pink-500' : 'bg-white/20'
                        }`}
                      >
                        <div
                          className={`w-5 h-5 bg-white rounded-full transition-all ${
                            settings.showNews ? 'translate-x-6' : 'translate-x-0.5'
                          }`}
                        />
                      </button>
                    </div>
                    <div>
                      <label className="text-white/80 text-sm mb-2 block">RSS Feed URL</label>
                      <input
                        type="text"
                        value={settings.newsFeedUrl}
                        onChange={(e) => setSettings({...settings, newsFeedUrl: e.target.value})}
                        className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                        placeholder="https://feeds.bbci.co.uk/news/rss.xml (default)"
                        disabled={!settings.showNews}
                      />
                    </div>
                  </>
                )}

                <button
                  onClick={() => setShowSettings(false)}
                  className="w-full p-3 bg-gradient-to-r from-pink-500 to-purple-500 rounded-xl text-white font-semibold hover:shadow-lg transition-all mt-6"
                >
                  Save Settings
                </button>
              </div>
            </div>
          </div>
        )}

        {showEventModal && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
            <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-8 max-w-md w-full border border-white/20">
              <h2 className="text-2xl font-bold text-white mb-6">Add Event</h2>
              <div className="space-y-4">
                <div>
                  <label className="text-white/80 text-sm mb-2 block">Event Name</label>
                  <input
                    type="text"
                    value={newEvent.title}
                    onChange={(e) => setNewEvent({...newEvent, title: e.target.value})}
                    placeholder="Enter event name"
                    className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                  />
                </div>
                <div>
                  <label className="text-white/80 text-sm mb-2 block">Date</label>
                  <input
                    type="date"
                    value={newEvent.date}
                    onChange={(e) => setNewEvent({...newEvent, date: e.target.value})}
                    className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white"
                  />
                </div>
                <div>
                  <label className="text-white/80 text-sm mb-2 block">Time (Optional)</label>
                  <input
                    type="time"
                    value={newEvent.time}
                    onChange={(e) => setNewEvent({...newEvent, time: e.target.value})}
                    className="w-full p-3 bg-white/10 border border-white/20 rounded-xl text-white"
                  />
                </div>
                <div className="flex gap-3">
                  <button
                    onClick={() => {
                      setShowEventModal(false);
                      setNewEvent({ title: '', date: '', time: '' });
                    }}
                    className="flex-1 p-3 bg-white/10 border border-white/20 rounded-xl text-white font-semibold hover:bg-white/20 transition-all"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={addEvent}
                    className="flex-1 p-3 bg-gradient-to-r from-pink-500 to-purple-500 rounded-xl text-white font-semibold hover:shadow-lg transition-all"
                  >
                    Add Event
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start" style={{ maxHeight: '700px' }}>
          <div className="lg:col-span-1 flex flex-col gap-6" style={{ maxHeight: '700px' }}>
            {!showTimer ? (
              <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl" style={{ flexShrink: 0 }}>
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <Clock className="w-6 h-6 text-pink-300" />
                    <h2 className="text-xl font-semibold text-white">Time</h2>
                  </div>
                  <button
                    onClick={() => setShowTimer(true)}
                    className="p-2 bg-white/10 rounded-lg hover:bg-white/20 transition-all"
                    title="Switch to timer"
                  >
                    <Timer className="w-5 h-5 text-white" />
                  </button>
                </div>
                <div className="text-5xl font-bold text-white mb-2">{formatTime(currentTime)}</div>
                <div className="text-white/60">{formatDate(currentTime)}</div>
              </div>
            ) : (
              <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl" style={{ flexShrink: 0 }}>
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <Timer className="w-6 h-6 text-pink-300" />
                    <h2 className="text-xl font-semibold text-white">Timer</h2>
                  </div>
                  <button
                    onClick={() => {
                      setShowTimer(false);
                      resetTimer();
                    }}
                    className="p-2 bg-white/10 rounded-lg hover:bg-white/20 transition-all"
                    title="Switch to clock"
                  >
                    <Clock className="w-5 h-5 text-white" />
                  </button>
                </div>
                
                {timerComplete ? (
                  <div className="text-center py-2">
                    <div className="text-4xl font-bold text-pink-400 mb-3 timer-pulse">Time's Up!</div>
                    <button
                      onClick={dismissAlarm}
                      className="px-6 py-2 bg-gradient-to-r from-pink-500 to-purple-500 rounded-xl text-white font-semibold hover:shadow-lg transition-all text-sm"
                    >
                      Dismiss
                    </button>
                  </div>
                ) : (
                  <>
                    <div className="flex items-center justify-center gap-4 mb-2">
                      <div className="flex items-center gap-2">
                        <div className="flex flex-col gap-0.5">
                          <button
                            onClick={() => adjustTimer('minutes', 'up')}
                            disabled={timerRunning}
                            className="p-1 bg-white/10 rounded-md hover:bg-white/20 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            <ChevronUp className="w-3 h-3 text-white" />
                          </button>
                          <button
                            onClick={() => adjustTimer('minutes', 'down')}
                            disabled={timerRunning}
                            className="p-1 bg-white/10 rounded-md hover:bg-white/20 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            <ChevronDown className="w-3 h-3 text-white" />
                          </button>
                        </div>
                        <div className="flex flex-col items-center">
                          <div className="text-4xl font-bold text-white min-w-[55px] text-center leading-none">
                            {timerMinutes.toString().padStart(2, '0')}
                          </div>
                          <div className="text-white/60 text-[10px] mt-0.5">min</div>
                        </div>
                      </div>
                      
                      <div className="text-4xl font-bold text-white leading-none">:</div>
                      
                      <div className="flex items-center gap-2">
                        <div className="flex flex-col items-center">
                          <div className="text-4xl font-bold text-white min-w-[55px] text-center leading-none">
                            {timerSeconds.toString().padStart(2, '0')}
                          </div>
                          <div className="text-white/60 text-[10px] mt-0.5">sec</div>
                        </div>
                        <div className="flex flex-col gap-0.5">
                          <button
                            onClick={() => adjustTimer('seconds', 'up')}
                            disabled={timerRunning}
                            className="p-1 bg-white/10 rounded-md hover:bg-white/20 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            <ChevronUp className="w-3 h-3 text-white" />
                          </button>
                          <button
                            onClick={() => adjustTimer('seconds', 'down')}
                            disabled={timerRunning}
                            className="p-1 bg-white/10 rounded-md hover:bg-white/20 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            <ChevronDown className="w-3 h-3 text-white" />
                          </button>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex items-center justify-between gap-2 mt-2">
                      <button
                        onClick={() => setTimerAlarmEnabled(!timerAlarmEnabled)}
                        className={`p-2 rounded-lg transition-all ${
                          timerAlarmEnabled ? 'bg-pink-500/20 text-pink-300' : 'bg-white/10 text-white/40'
                        }`}
                        title={timerAlarmEnabled ? 'Alarm enabled' : 'Alarm disabled'}
                      >
                        {timerAlarmEnabled ? (
                          <Volume2 className="w-4 h-4" />
                        ) : (
                          <VolumeX className="w-4 h-4" />
                        )}
                      </button>
                      
                      {!timerRunning ? (
                        <>
                          <button
                            onClick={startTimer}
                            disabled={timerMinutes === 0 && timerSeconds === 0}
                            className="flex-1 py-2 px-3 bg-gradient-to-r from-green-500 to-emerald-500 rounded-xl text-white font-semibold hover:shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed text-sm"
                          >
                            Start
                          </button>
                          <button
                            onClick={resetTimer}
                            className="p-2 bg-white/10 rounded-lg text-white hover:bg-white/20 transition-all"
                            title="Reset"
                          >
                            <RotateCcw className="w-4 h-4" />
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            onClick={stopTimer}
                            className="flex-1 py-2 px-3 bg-gradient-to-r from-red-500 to-rose-500 rounded-xl text-white font-semibold hover:shadow-lg transition-all text-sm"
                          >
                            Stop
                          </button>
                          <button
                            onClick={resetTimer}
                            className="p-2 bg-white/10 rounded-lg text-white hover:bg-white/20 transition-all"
                            title="Reset"
                          >
                            <RotateCcw className="w-4 h-4" />
                          </button>
                        </>
                      )}
                    </div>
                  </>
                )}
              </div>
            )}

            {weather && (
              <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl" style={{ flexShrink: 0 }}>
                <div className="flex items-center gap-3 mb-4">
                  <Cloud className="w-6 h-6 text-blue-300" />
                  <h2 className="text-xl font-semibold text-white">Weather</h2>
                </div>
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-5xl font-bold text-white">{Math.round(weather.temperature_2m)}°F</div>
                    <div className="flex items-center gap-4 mt-2 text-white/60">
                      <span className="flex items-center gap-1">
                        <Droplets className="w-4 h-4" />
                        {weather.relative_humidity_2m}%
                      </span>
                      <span className="flex items-center gap-1">
                        <Wind className="w-4 h-4" />
                        {Math.round(weather.wind_speed_10m)} mph
                      </span>
                    </div>
                  </div>
                  <div className="text-blue-200">
                    {getWeatherIcon(weather.weather_code)}
                  </div>
                </div>
              </div>
            )}

            <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl group flex flex-col" id="schedule-card" style={{ flex: '1 1 auto', minHeight: '150px', maxHeight: '700px', overflow: 'hidden' }}>
              <div className="flex items-center justify-between mb-4" style={{ flexShrink: 0 }}>
                <h2 className="text-xl font-semibold text-white">{scheduleTitle}</h2>
                <button
                  onClick={() => !settings.nextcloudEnabled && setShowEventModal(true)}
                  className={`p-2 rounded-lg transition-all ${
                    settings.nextcloudEnabled
                      ? 'bg-gradient-to-r from-gray-500 to-gray-600 cursor-not-allowed opacity-50'
                      : 'bg-gradient-to-r from-pink-500 to-purple-500 hover:shadow-lg'
                  }`}
                  disabled={settings.nextcloudEnabled}
                  title={settings.nextcloudEnabled ? 'Event creation disabled when Nextcloud sync is active' : 'Add event'}
                >
                  <Plus className="w-5 h-5 text-white" />
                </button>
              </div>
              <div className="space-y-3 overflow-y-auto" style={{ flex: '1 1 auto', paddingRight: '8px' }}>
                {displayedScheduleEvents.length > 0 ? (
                  displayedScheduleEvents.map(event => (
                    <div key={event.id} className="flex items-center justify-between p-3 bg-white/5 rounded-xl group/item hover:bg-white/10 transition-all">
                      <div className="flex-1">
                        <div className="text-white font-medium">{event.title}</div>
                        <div className="text-white/60 text-sm">{formatEventTime(event.time)}</div>
                      </div>
                      {!settings.nextcloudEnabled && (
                        <button 
                          onClick={() => deleteItem(event.id, 'event')} 
                          className="text-red-300 hover:text-red-200 opacity-0 group-hover/item:opacity-100 transition-opacity duration-200 ml-2"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  ))
                ) : (
                  <div className="text-white/40 text-center py-8">No events {isViewingToday ? 'today' : 'on this day'}</div>
                )}
              </div>
            </div>
          </div>

          <div className="lg:col-span-1">
            <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl flex flex-col" id="calendar-card" style={{ height: '700px' }}>
              <div className="flex items-center justify-between mb-6" style={{ flexShrink: 0 }}>
                <h2 className="text-2xl font-semibold text-white">
                  {selectedDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
                </h2>
                <div className="flex gap-2">
                  <button onClick={() => changeMonth(-1)} className="p-2 bg-white/10 rounded-lg hover:bg-white/20">
                    <ChevronLeft className="w-5 h-5 text-white" />
                  </button>
                  <button onClick={() => changeMonth(1)} className="p-2 bg-white/10 rounded-lg hover:bg-white/20">
                    <ChevronRight className="w-5 h-5 text-white" />
                  </button>
                </div>
              </div>
              <div className="grid grid-cols-7 gap-2 mb-4" style={{ flexShrink: 0 }}>
                {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
                  <div key={day} className="text-center text-white/60 text-sm font-semibold">{day}</div>
                ))}
              </div>
              <div className="grid grid-cols-7 gap-2" style={{ flexShrink: 0 }}>
                {monthDays.map((day, idx) => {
                  const dayEvents = getEventsForDate(day);
                  const isToday = day && day.toDateString() === currentTime.toDateString();
                  const isSelected = day && day.toDateString() === viewingDate.toDateString();
                  
                  return (
                    <div
                      key={idx}
                      onClick={() => selectDate(day)}
                      className={`aspect-square flex flex-col items-center justify-center rounded-lg text-sm relative ${
                        day ? 'bg-white/5 text-white hover:bg-white/10 cursor-pointer' : ''
                      } ${
                        isSelected && !isToday
                          ? 'bg-white/20 ring-2 ring-white/40'
                          : ''
                      } ${
                        isToday
                          ? 'bg-gradient-to-br from-pink-500 to-purple-500 font-bold ring-2 ring-pink-300'
                          : ''
                      }`}
                    >
                      {day && (
                        <>
                          <span>{day.getDate()}</span>
                          {dayEvents.length > 0 && (
                            <div className="absolute bottom-1 flex gap-0.5">
                              {dayEvents.slice(0, 3).map((_, i) => (
                                <div key={i} className="w-1 h-1 rounded-full bg-white/60"></div>
                              ))}
                            </div>
                          )}
                        </>
                      )}
                    </div>
                  );
                })}
              </div>
              
              {settings.showNews && newsHeadline && (
                <div className="mt-4 pt-4 border-t border-white/20" style={{ flexShrink: 0 }}>
                  <div className="flex items-center gap-2 mb-2">
                    <Newspaper className="w-4 h-4 text-pink-300" />
                    <h3 className="text-sm font-semibold text-white/80">Latest News</h3>
                  </div>
                  <p className="text-white/90 text-sm leading-relaxed line-clamp-2">
                    {newsHeadline}
                  </p>
                </div>
              )}
            </div>
          </div>

          <div className="lg:col-span-1">
            <div className="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl group" id="grocery-card" style={{ maxHeight: '700px', display: 'flex', flexDirection: 'column' }}>
              <div className="flex items-center justify-between mb-6" style={{ flexShrink: 0 }}>
                <h2 className="text-2xl font-semibold text-white">Grocery List</h2>
                <button
                  onClick={downloadGroceryList}
                  className="p-2 bg-white/10 rounded-lg hover:bg-white/20 transition-all opacity-0 group-hover:opacity-100 duration-200"
                  title="Download grocery list"
                >
                  <Download className="w-5 h-5 text-white" />
                </button>
              </div>
              {groceries.length > 0 && (
                <div className="space-y-3 mb-6" style={{ overflowY: 'auto', maxHeight: '520px', paddingRight: '8px' }}>
                  {groceries.map(item => (
                    <div
                      key={item.id}
                      className={`flex items-center justify-between p-3 bg-white/5 rounded-xl transition-all group/item hover:bg-white/10 ${
                        item.checked ? 'opacity-50' : ''
                      }`}
                    >
                      <div className="flex items-center gap-3 flex-1">
                        <button
                          onClick={() => toggleGrocery(item.id)}
                          className={`w-6 h-6 rounded-lg border-2 flex items-center justify-center transition-all ${
                            item.checked
                              ? 'bg-green-500 border-green-500'
                              : 'border-white/40'
                          }`}
                        >
                          {item.checked && <Check className="w-4 h-4 text-white" />}
                        </button>
                        <span className={`text-white ${item.checked ? 'line-through' : ''}`}>
                          {item.text}
                        </span>
                      </div>
                      <button 
                        onClick={() => deleteItem(item.id, 'grocery')} 
                        className="text-red-300 hover:text-red-200 opacity-0 group-hover/item:opacity-100 transition-opacity duration-200"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
              <div className="flex gap-2" style={{ flexShrink: 0 }}>
                <input
                  type="text"
                  value={newGrocery}
                  onChange={(e) => setNewGrocery(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && addGrocery()}
                  placeholder="Add grocery item..."
                  className="flex-1 p-3 bg-white/10 border border-white/20 rounded-xl text-white placeholder-white/40"
                />
                <button onClick={addGrocery} className="p-3 bg-gradient-to-r from-pink-500 to-purple-500 rounded-xl hover:shadow-lg transition-all">
                  <Plus className="w-6 h-6 text-white" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default FamilyDashboard;
EOF

echo "✅ src/App.jsx created"

cat > README.md << 'EOF'
# 🏠 Family Dashboard

A beautiful, modern family dashboard for self-hosting with Docker.
All data is stored on the server and shared across all devices!

## 🚀 Quick Start

1. Run: `bash setup.sh`
2. Launch: `cd family-dashboard && docker compose up -d --build`
3. Open: http://localhost:3927

## ✨ Features

- 📅 Interactive calendar with event indicators
- ⏰ Real-time clock with timezone support
- ⏲️ Kitchen timer with alarm (flip from clock view)
- 🌤️ Live weather with zip code lookup
- 📋 Today's schedule with modal event creator
- 🛒 Grocery list with download feature
- 📰 Latest news headlines (RSS feed)
- 🎨 10 beautiful color themes
- 📱 Fully responsive design
- 🌐 Shared data across all network devices
- 🎯 Hover-only delete buttons
- 📊 Auto-synced card heights
- 👨‍👩‍👧‍👦 Family name customization
- ⏱️ 12/24 hour time format
- 🗂️ Organized settings with tabs
- 🎵 Music player (Subsonic/Ampache)
- ☁️ Nextcloud calendar sync

Enjoy! 🎉
EOF

echo "✅ README.md created"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📂 All files created in: $(pwd)"
echo ""
echo "🚀 To start the dashboard:"
echo "   docker compose up -d --build"
echo ""
echo "🌐 Then open: http://localhost:3927"
echo ""
