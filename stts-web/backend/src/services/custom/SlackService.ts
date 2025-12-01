import { BaseService, ServiceStatus } from '../base/Service';
import { HttpClient } from '../base/HttpClient';
import * as cheerio from 'cheerio';

/**
 * Slack service implementation
 * Uses HTML parsing to extract status from Slack's status page
 */
export class SlackService extends BaseService {
  async updateStatus(): Promise<void> {
    try {
      const html = await HttpClient.loadHTML(this.config.url);
      const $ = cheerio.load(html);

      // Parse service status images
      const serviceImages = $('#services .service.header img');

      if (serviceImages.length === 0) {
        throw new Error('Unexpected response: No service images found');
      }

      const imageURLs: string[] = [];
      serviceImages.each((_, el) => {
        const src = $(el).attr('src');
        if (src) imageURLs.push(src);
      });

      const statuses = imageURLs.map((url) => this.parseSlackStatus(url));
      const worstStatus = Math.max(...statuses, ServiceStatus.Undetermined);

      const message = $('#current_status h1').text().trim() || 'All Systems Operational';

      this.statusDescription = {
        status: worstStatus,
        message,
      };
    } catch (error) {
      this.fail(error as Error);
    }
  }

  private parseSlackStatus(imageUrl: string): ServiceStatus {
    const fileName = imageUrl.toLowerCase().split('/').pop() || '';

    if (fileName.includes('tablecheck.png')) {
      return ServiceStatus.Good;
    } else if (fileName.includes('tableoutage.png')) {
      return ServiceStatus.Major;
    } else if (fileName.includes('tableincident.png')) {
      return ServiceStatus.Minor;
    } else if (fileName.includes('tablemaintenance.png')) {
      return ServiceStatus.Maintenance;
    } else if (fileName.includes('tablenotice.png')) {
      return ServiceStatus.Notice;
    }

    return ServiceStatus.Undetermined;
  }
}
