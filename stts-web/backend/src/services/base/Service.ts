// Base service types and classes, mirroring the Swift implementation

export enum ServiceStatus {
  Undetermined = 0,
  Good = 1,
  Notice = 2,
  Maintenance = 3,
  Minor = 4,
  Major = 5,
}

export interface ServiceStatusDescription {
  status: ServiceStatus;
  message: string;
}

export interface ServiceConfig {
  id: string;
  name: string;
  url: string;
  type: string;
  [key: string]: any; // Additional properties based on service type
}

export abstract class BaseService {
  protected statusDescription: ServiceStatusDescription = {
    status: ServiceStatus.Undetermined,
    message: 'Loading…',
  };

  constructor(public config: ServiceConfig) {}

  get status(): ServiceStatus {
    return this.statusDescription.status;
  }

  get message(): string {
    return this.statusDescription.message;
  }

  get name(): string {
    return this.config.name;
  }

  get url(): string {
    return this.config.url;
  }

  get id(): string {
    return this.config.id;
  }

  /**
   * Update the service status by fetching from the service endpoint
   */
  abstract updateStatus(): Promise<void>;

  /**
   * Mark service as failed with error
   */
  protected fail(error: Error | string): void {
    const message = typeof error === 'string'
      ? error
      : error.message || 'Unexpected error';

    this.statusDescription = {
      status: ServiceStatus.Undetermined,
      message,
    };
  }

  /**
   * Convert service to JSON for API response
   */
  toJSON() {
    return {
      id: this.id,
      name: this.name,
      url: this.url,
      status: this.status,
      statusName: ServiceStatus[this.status],
      message: this.message,
      type: this.config.type,
    };
  }
}
