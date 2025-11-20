# STTS Web - Service Status Monitor

A cross-platform web application for monitoring the status of cloud services. Converted from the macOS-only [stts](https://github.com/inket/stts) application.

![Dashboard Preview](https://via.placeholder.com/800x400?text=STTS+Dashboard)

## Features

- 🌐 **Web-based**: Access from any device with a browser
- 🔄 **Real-time updates**: Automatically refreshes service statuses
- 🎨 **Clean UI**: Dark theme with color-coded status indicators
- 🔍 **Search**: Quickly find services
- 📊 **Statistics**: See operational status at a glance
- ⚡ **Fast**: Parallel status checking for quick updates
- 🔧 **Extensible**: Easy to add new services

## Status Indicators

- 🟢 **Good**: Service is operational
- 🔵 **Notice**: Service has a notice/announcement
- 🟡 **Minor**: Service experiencing minor issues
- 🟠 **Major**: Service experiencing major issues
- 🟠 **Maintenance**: Service under maintenance
- ⚫ **Undetermined**: Status cannot be determined

## Quick Start

### Prerequisites

- Node.js 18+ and npm
- Ruby (for adding new services via extract script)

### Installation

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd stts-web
```

2. **Install backend dependencies**
```bash
cd backend
npm install
```

3. **Install frontend dependencies**
```bash
cd ../frontend
npm install
```

### Running the Application

1. **Start the backend API** (from `backend/` directory):
```bash
npm run dev
```
The API will run on `http://localhost:3001`

2. **Start the frontend** (from `frontend/` directory):
```bash
npm run dev
```
The UI will run on `http://localhost:3000`

3. **Open your browser** and navigate to `http://localhost:3000`

## Project Structure

```
stts-web/
├── backend/                    # Backend API server
│   ├── src/
│   │   ├── services/          # Service checker implementations
│   │   │   ├── base/          # Base classes (Service, HttpClient)
│   │   │   ├── statuspage/    # StatusPage.io services
│   │   │   └── custom/        # Custom service implementations
│   │   ├── api/               # Express API routes
│   │   ├── config/            # Service definitions (JSON)
│   │   └── index.ts           # Main entry point
│   └── package.json
├── frontend/                   # React frontend
│   ├── src/
│   │   ├── components/        # React components
│   │   ├── styles/            # CSS styles
│   │   └── App.tsx            # Main app component
│   └── package.json
├── scripts/                    # Utility scripts
│   └── extract.rb             # Script for adding new services
└── README.md
```

## Adding New Services

### Method 1: Using the Extract Script (Recommended)

The extract script can automatically detect and add services from status pages:

```bash
cd scripts
bundle install
bundle exec ruby extract.rb <status-page-url>

# Examples:
bundle exec ruby extract.rb https://status.notion.so/
bundle exec ruby extract.rb https://status.dropbox.com/
```

The script will output the service configuration which you can add to `backend/src/config/services.json`.

### Method 2: Manual Configuration

Add a new entry to `backend/src/config/services.json`:

#### For StatusPage.io services:
```json
{
  "id": "servicename",
  "name": "Service Name",
  "url": "https://status.servicename.com",
  "type": "statuspage",
  "statusPageID": "xxxxxxxxxxxxx",
  "domain": "statuspage.io"
}
```

#### For custom services:
1. Create a new service class in `backend/src/services/custom/`
2. Register it in `backend/src/services/ServiceFactory.ts`
3. Add configuration to `services.json`

## Supported Service Types

### Built-in Support

1. **StatusPage.io** (most common)
   - GitHub, GitLab, Heroku, Stripe, Cloudflare, etc.
   - Uses the StatusPage.io API

2. **Slack** (custom implementation)
   - HTML parsing-based checker

### Adding New Service Types

To add support for a new status page platform:

1. **Create a new service class** in `backend/src/services/`:

```typescript
import { BaseService, ServiceStatus } from '../base/Service';
import { HttpClient } from '../base/HttpClient';

export class MyServiceType extends BaseService {
  async updateStatus(): Promise<void> {
    try {
      // Fetch data from the service
      const data = await HttpClient.loadJSON(this.config.url);

      // Parse and set status
      this.statusDescription = {
        status: ServiceStatus.Good,
        message: 'All systems operational',
      };
    } catch (error) {
      this.fail(error as Error);
    }
  }
}
```

2. **Register it** in `ServiceFactory.ts`:

```typescript
ServiceFactory.registerServiceType('myservicetype', MyServiceType);
```

3. **Add services** using this type in `services.json`.

## API Endpoints

The backend provides the following REST API endpoints:

- `GET /api/services` - Get all services with current status
- `GET /api/services/:id` - Get a specific service
- `POST /api/services/:id/update` - Update a specific service
- `POST /api/services/update-all` - Update all services
- `GET /api/health` - Health check

## Configuration

### Backend Configuration

Edit `backend/src/index.ts` or use environment variables:

- `PORT` - API server port (default: 3001)
- `UPDATE_INTERVAL` - Update interval in minutes (default: 5)

### Frontend Configuration

Edit `frontend/vite.config.ts` to change:
- Development server port (default: 3000)
- API proxy settings

## Production Deployment

### Backend

```bash
cd backend
npm run build
npm start
```

### Frontend

```bash
cd frontend
npm run build
```

Serve the `frontend/dist` folder with any static file server or CDN.

## Maintaining Service Definitions

The core advantage of this architecture is that you can **keep service definitions updated** without changing code:

1. Services are defined in JSON files
2. Use the extract script to add new services automatically
3. The original stts repository can be a reference for new services
4. Service checkers are modular and reusable

## Converting Services from Original STTS

If you want to convert more services from the original macOS app:

1. Check the service type in the Swift code
2. If it uses `StatusPageService`, just add the JSON config
3. If it's custom, you may need to implement a new checker class
4. Most services (300+) use StatusPage.io and can be added easily

## Contributing

To add new services:

1. Use the extract script or manually add configuration
2. Test the service loads correctly
3. Verify status updates work
4. Submit a pull request

## Known Service Types in Original STTS

The original app supports these platforms (you can add support for more):

- StatusPage.io (most common, ~100+ services)
- Instatus
- Status.io v1
- AWS Services
- Azure Services
- Google Cloud Platform
- Apple Services
- Better Stack
- PagerDuty
- Firebase
- And many custom implementations

## License

Based on the original [stts](https://github.com/inket/stts) project by [@inket](https://github.com/inket).

## Credits

Original macOS app: [stts by inket](https://github.com/inket/stts)
