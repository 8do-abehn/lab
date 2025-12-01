import { Router, Request, Response } from 'express';
import { ServiceManager } from '../services/ServiceManager';

export function createApiRoutes(serviceManager: ServiceManager): Router {
  const router = Router();

  /**
   * GET /api/services
   * Get all services with their current status
   */
  router.get('/services', (req: Request, res: Response) => {
    try {
      const services = serviceManager.toJSON();
      res.json({
        success: true,
        count: services.length,
        services,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve services',
      });
    }
  });

  /**
   * GET /api/services/:id
   * Get a specific service by ID
   */
  router.get('/services/:id', (req: Request, res: Response) => {
    try {
      const service = serviceManager.getService(req.params.id);

      if (!service) {
        return res.status(404).json({
          success: false,
          error: 'Service not found',
        });
      }

      res.json({
        success: true,
        service: service.toJSON(),
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve service',
      });
    }
  });

  /**
   * POST /api/services/:id/update
   * Trigger an immediate update for a specific service
   */
  router.post('/services/:id/update', async (req: Request, res: Response) => {
    try {
      const service = await serviceManager.updateService(req.params.id);

      if (!service) {
        return res.status(404).json({
          success: false,
          error: 'Service not found',
        });
      }

      res.json({
        success: true,
        service: service.toJSON(),
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: 'Failed to update service',
      });
    }
  });

  /**
   * POST /api/services/update-all
   * Trigger an immediate update for all services
   */
  router.post('/services/update-all', async (req: Request, res: Response) => {
    try {
      await serviceManager.updateAllServices();

      res.json({
        success: true,
        message: 'All services updated',
        services: serviceManager.toJSON(),
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: 'Failed to update services',
      });
    }
  });

  /**
   * GET /api/health
   * Health check endpoint
   */
  router.get('/health', (req: Request, res: Response) => {
    res.json({
      success: true,
      status: 'healthy',
      timestamp: new Date().toISOString(),
    });
  });

  return router;
}
