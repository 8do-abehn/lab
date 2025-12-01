import { BaseService, ServiceConfig } from './base/Service';
import { StatusPageService } from './statuspage/StatusPageService';
import { SlackService } from './custom/SlackService';

/**
 * Factory for creating service instances based on their type
 * This allows easy addition of new service types
 */
export class ServiceFactory {
  private static serviceTypes: Map<string, new (config: ServiceConfig) => BaseService> = new Map([
    ['statuspage', StatusPageService],
    ['slack', SlackService],
    // Add more service types here as they are implemented
  ]);

  /**
   * Register a new service type
   */
  static registerServiceType(type: string, serviceClass: new (config: ServiceConfig) => BaseService): void {
    this.serviceTypes.set(type, serviceClass);
  }

  /**
   * Create a service instance from configuration
   */
  static createService(config: ServiceConfig): BaseService {
    const ServiceClass = this.serviceTypes.get(config.type);

    if (!ServiceClass) {
      throw new Error(`Unknown service type: ${config.type}`);
    }

    return new ServiceClass(config);
  }

  /**
   * Create multiple service instances from configurations
   */
  static createServices(configs: ServiceConfig[]): BaseService[] {
    return configs.map((config) => this.createService(config));
  }

  /**
   * Get all registered service types
   */
  static getServiceTypes(): string[] {
    return Array.from(this.serviceTypes.keys());
  }
}
