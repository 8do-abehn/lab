import { BaseService, ServiceStatus, ServiceStatusDescription } from '../base/Service';
import { HttpClient } from '../base/HttpClient';

/**
 * StatusPage.io service implementation
 * Handles services hosted on StatusPage.io platform
 */

interface StatusPageComponent {
  id: string;
  name: string;
  status: 'operational' | 'major_outage' | 'degraded_performance' | 'partial_outage' | 'under_maintenance';
  position: number;
  group_id: string | null;
  group: boolean;
}

interface StatusPageIncident {
  id: string;
  name: string;
  status: 'investigating' | 'identified' | 'monitoring' | 'resolved' | 'postmortem';
}

interface StatusPageStatus {
  description: string;
  indicator: 'none' | 'minor' | 'major' | 'critical' | 'maintenance';
}

interface StatusPageSummary {
  components: StatusPageComponent[];
  incidents: StatusPageIncident[];
  status: StatusPageStatus;
}

export class StatusPageService extends BaseService {
  async updateStatus(): Promise<void> {
    try {
      const statusPageID = this.config.statusPageID;
      const domain = this.config.domain || 'statuspage.io';

      if (!statusPageID) {
        throw new Error('statusPageID is required for StatusPage services');
      }

      const summaryURL = `https://${statusPageID}.${domain}/api/v2/summary.json`;
      const summary = await HttpClient.loadJSON<StatusPageSummary>(summaryURL);

      this.updateStatusFromSummary(summary);
    } catch (error) {
      this.fail(error as Error);
    }
  }

  private updateStatusFromSummary(summary: StatusPageSummary): void {
    // Map indicator to service status
    const status = this.mapIndicatorToStatus(summary.status.indicator);

    // Check for unresolved incidents
    const unresolvedIncidents = summary.incidents.filter(
      (incident) => ['investigating', 'identified', 'monitoring'].includes(incident.status)
    );

    if (unresolvedIncidents.length > 0) {
      const prefix = unresolvedIncidents.length > 1 ? '*' : '';
      const message = unresolvedIncidents
        .map((incident) => {
          const statusPrefix = incident.status === 'monitoring' ? 'Monitoring:' : '';
          return [prefix, statusPrefix, incident.name].filter(Boolean).join(' ');
        })
        .join('\n');

      this.statusDescription = { status, message };
      return;
    }

    // Check for affected components
    const affectedComponents = summary.components.filter(
      (component) => component.status !== 'operational'
    );

    if (affectedComponents.length > 0) {
      const prefix = affectedComponents.length > 1 ? '* ' : '';
      const message = affectedComponents
        .map((component) => `${prefix}${component.name}`)
        .join('\n');

      this.statusDescription = { status, message };
      return;
    }

    // Fallback to status description
    this.statusDescription = {
      status,
      message: summary.status.description,
    };
  }

  private mapIndicatorToStatus(indicator: string): ServiceStatus {
    switch (indicator) {
      case 'none':
        return ServiceStatus.Good;
      case 'minor':
        return ServiceStatus.Minor;
      case 'major':
      case 'critical':
        return ServiceStatus.Major;
      case 'maintenance':
        return ServiceStatus.Maintenance;
      default:
        return ServiceStatus.Undetermined;
    }
  }
}
