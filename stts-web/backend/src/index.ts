import express from 'express';
import cors from 'cors';
import path from 'path';
import { ServiceManager } from './services/ServiceManager';
import { createApiRoutes } from './api/routes';

const app = express();
const PORT = process.env.PORT || 3001;
const UPDATE_INTERVAL_MINUTES = parseInt(process.env.UPDATE_INTERVAL || '5');

// Middleware
app.use(cors());
app.use(express.json());

// Initialize service manager
const serviceManager = new ServiceManager();

// Load services from configuration
const configPath = path.join(__dirname, 'config', 'services.json');
try {
  serviceManager.loadServicesFromConfig(configPath);
} catch (error) {
  console.error('Failed to load services:', error);
  process.exit(1);
}

// Start periodic updates
serviceManager.startPeriodicUpdates(UPDATE_INTERVAL_MINUTES);

// API routes
app.use('/api', createApiRoutes(serviceManager));

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'STTS Web API',
    version: '1.0.0',
    description: 'Service status monitoring API',
    endpoints: {
      health: '/api/health',
      services: '/api/services',
      service: '/api/services/:id',
      updateService: '/api/services/:id/update',
      updateAll: '/api/services/update-all',
    },
  });
});

// Error handling
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`\n🚀 STTS Web API running on http://localhost:${PORT}`);
  console.log(`📊 Monitoring ${serviceManager.getAllServices().length} services`);
  console.log(`🔄 Update interval: ${UPDATE_INTERVAL_MINUTES} minutes\n`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down gracefully...');
  serviceManager.stopPeriodicUpdates();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\nShutting down gracefully...');
  serviceManager.stopPeriodicUpdates();
  process.exit(0);
});
