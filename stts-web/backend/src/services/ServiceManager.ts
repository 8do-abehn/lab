import { BaseService, ServiceConfig } from './base/Service';
import { ServiceFactory } from './ServiceFactory';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Manages all service instances and provides methods to update them
 */
export class ServiceManager {
  private services: Map<string, BaseService> = new Map();
  private updateInterval: NodeJS.Timer | null = null;

  constructor() {}

  /**
   * Load services from configuration file
   */
  loadServicesFromConfig(configPath: string): void {
    const configData = fs.readFileSync(configPath, 'utf-8');
    const configs: ServiceConfig[] = JSON.parse(configData);

    this.loadServices(configs);
  }

  /**
   * Load services from configuration objects
   */
  loadServices(configs: ServiceConfig[]): void {
    const services = ServiceFactory.createServices(configs);

    services.forEach((service) => {
      this.services.set(service.id, service);
    });

    console.log(`Loaded ${this.services.size} services`);
  }

  /**
   * Get a service by ID
   */
  getService(id: string): BaseService | undefined {
    return this.services.get(id);
  }

  /**
   * Get all services
   */
  getAllServices(): BaseService[] {
    return Array.from(this.services.values());
  }

  /**
   * Update a specific service
   */
  async updateService(id: string): Promise<BaseService | null> {
    const service = this.services.get(id);
    if (!service) {
      return null;
    }

    await service.updateStatus();
    return service;
  }

  /**
   * Update all services
   */
  async updateAllServices(): Promise<void> {
    console.log('Updating all services...');
    const startTime = Date.now();

    const updatePromises = Array.from(this.services.values()).map((service) =>
      service.updateStatus().catch((error) => {
        console.error(`Error updating ${service.name}:`, error.message);
      })
    );

    await Promise.all(updatePromises);

    const duration = Date.now() - startTime;
    console.log(`Updated ${this.services.size} services in ${duration}ms`);
  }

  /**
   * Start periodic updates
   */
  startPeriodicUpdates(intervalMinutes: number = 5): void {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }

    // Update immediately on start
    this.updateAllServices();

    // Then update periodically
    this.updateInterval = setInterval(
      () => this.updateAllServices(),
      intervalMinutes * 60 * 1000
    );

    console.log(`Started periodic updates every ${intervalMinutes} minutes`);
  }

  /**
   * Stop periodic updates
   */
  stopPeriodicUpdates(): void {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
      console.log('Stopped periodic updates');
    }
  }

  /**
   * Get services as JSON
   */
  toJSON() {
    return Array.from(this.services.values()).map((service) => service.toJSON());
  }
}
