# Quick Start Guide

Get STTS Web up and running in 5 minutes!

## Prerequisites

```bash
# Check you have Node.js installed
node --version  # Should be 18 or higher
npm --version

# Check you have Ruby installed (optional, only for adding new services)
ruby --version
```

## Installation & Setup

### 1. Install Dependencies

```bash
# Install backend dependencies
cd backend
npm install

# Install frontend dependencies
cd ../frontend
npm install
```

### 2. Start the Application

Open two terminal windows:

**Terminal 1 - Backend:**
```bash
cd backend
npm run dev
```

You should see:
```
🚀 STTS Web API running on http://localhost:3001
📊 Monitoring 15 services
🔄 Update interval: 5 minutes
```

**Terminal 2 - Frontend:**
```bash
cd frontend
npm run dev
```

You should see:
```
VITE ready in XXX ms
➜  Local:   http://localhost:3000/
```

### 3. Open Your Browser

Navigate to: http://localhost:3000

You should see the STTS dashboard with 15 pre-configured services!

## What's Included

The starter configuration includes these popular services:

- GitHub
- GitLab
- Slack
- Stripe
- Heroku
- Cloudflare
- DigitalOcean
- Vercel
- Netlify
- Docker
- npm
- Datadog
- Twilio
- Zoom
- PagerDuty

## Next Steps

### Add More Services

**Option 1: Use the extract script**
```bash
cd scripts
bundle install
bundle exec ruby extract.rb https://status.notion.so/
```

**Option 2: Manually edit the config**
```bash
# Edit backend/src/config/services.json
# Add your service configuration
```

See [ADDING_SERVICES.md](ADDING_SERVICES.md) for detailed instructions.

### Customize Update Interval

Edit `backend/src/index.ts`:
```typescript
const UPDATE_INTERVAL_MINUTES = 5; // Change this value
```

Or set an environment variable:
```bash
UPDATE_INTERVAL=10 npm run dev
```

### Production Build

**Backend:**
```bash
cd backend
npm run build
npm start
```

**Frontend:**
```bash
cd frontend
npm run build
# Serve the dist/ folder with any static file server
```

## Troubleshooting

### Backend won't start
- Check if port 3001 is already in use
- Verify `services.json` has valid JSON syntax
- Check Node.js version is 18+

### Frontend won't connect to backend
- Ensure backend is running on port 3001
- Check the proxy settings in `frontend/vite.config.ts`
- Look for CORS errors in browser console

### Services show "Undetermined" status
- Wait for the first update cycle (up to 5 minutes)
- Check backend logs for errors
- Verify the service configuration is correct
- Try manually updating: `curl -X POST http://localhost:3001/api/services/update-all`

### "Failed to connect to server" error
- Ensure backend is running
- Check firewall settings
- Verify the API URL in frontend code

## Architecture Overview

```
┌─────────────────┐
│   Frontend      │  React app on localhost:3000
│   (Vite)        │  Displays service statuses
└────────┬────────┘
         │ HTTP requests
         ↓
┌─────────────────┐
│   Backend API   │  Express server on localhost:3001
│   (Node.js)     │  Fetches and caches service statuses
└────────┬────────┘
         │ HTTP requests
         ↓
┌─────────────────┐
│  Status Pages   │  External service status APIs
│  (Internet)     │  (StatusPage.io, custom APIs, etc.)
└─────────────────┘
```

## API Endpoints

Once running, you can access these endpoints:

- `GET http://localhost:3001/api/services` - All services
- `GET http://localhost:3001/api/services/github` - Specific service
- `POST http://localhost:3001/api/services/update-all` - Force update
- `GET http://localhost:3001/api/health` - Health check

Example:
```bash
curl http://localhost:3001/api/services | jq
```

## Development Tips

### Watch mode for backend
```bash
cd backend
npm run dev  # Auto-restarts on file changes
```

### Hot reload for frontend
```bash
cd frontend
npm run dev  # Hot reloads on file changes
```

### TypeScript type checking
```bash
# Backend
cd backend
npm run check

# Frontend
cd frontend
npm run build  # Will fail if there are type errors
```

## Project Structure Quick Reference

```
stts-web/
├── backend/
│   ├── src/
│   │   ├── config/
│   │   │   └── services.json      ← Add services here
│   │   ├── services/
│   │   │   ├── base/               ← Core service classes
│   │   │   ├── statuspage/         ← StatusPage.io implementation
│   │   │   └── custom/             ← Custom service implementations
│   │   ├── api/
│   │   │   └── routes.ts           ← API endpoints
│   │   └── index.ts                ← Main server file
│   └── package.json
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   └── ServiceCard.tsx     ← Service display component
│   │   ├── styles/
│   │   │   └── App.css             ← Styling
│   │   ├── App.tsx                 ← Main app component
│   │   └── types.ts                ← TypeScript types
│   └── package.json
└── scripts/
    └── extract.rb                  ← Service discovery script
```

## Need More Help?

- 📖 [README.md](README.md) - Full documentation
- 🔧 [ADDING_SERVICES.md](ADDING_SERVICES.md) - How to add services
- 🐛 Check backend logs for detailed error messages
- 🔍 Use browser DevTools to inspect network requests

## Contributing

Want to add more service types or features? Check out the codebase and submit a PR!
