export enum ServiceStatus {
  Undetermined = 0,
  Good = 1,
  Notice = 2,
  Maintenance = 3,
  Minor = 4,
  Major = 5,
}

export interface Service {
  id: string;
  name: string;
  url: string;
  status: ServiceStatus;
  statusName: string;
  message: string;
  type: string;
}

export interface ApiResponse {
  success: boolean;
  count?: number;
  services?: Service[];
  error?: string;
}
