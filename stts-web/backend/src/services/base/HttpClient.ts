import axios, { AxiosRequestConfig, AxiosResponse } from 'axios';

/**
 * HTTP client for fetching service status data
 * Mirrors the Loading protocol from Swift
 */
export class HttpClient {
  private static readonly DEFAULT_TIMEOUT = 30000;
  private static readonly DEFAULT_HEADERS = {
    'User-Agent': 'STTS-Web/1.0',
  };

  /**
   * Load data from a URL
   */
  static async loadData(
    url: string,
    options: AxiosRequestConfig = {}
  ): Promise<{ data: any; response: AxiosResponse }> {
    const config: AxiosRequestConfig = {
      timeout: this.DEFAULT_TIMEOUT,
      headers: { ...this.DEFAULT_HEADERS, ...options.headers },
      ...options,
    };

    const response = await axios.get(url, config);
    return { data: response.data, response };
  }

  /**
   * Load JSON data from a URL
   */
  static async loadJSON<T = any>(
    url: string,
    options: AxiosRequestConfig = {}
  ): Promise<T> {
    const { data } = await this.loadData(url, {
      ...options,
      headers: {
        Accept: 'application/json',
        ...options.headers,
      },
    });
    return data as T;
  }

  /**
   * Load HTML data from a URL
   */
  static async loadHTML(
    url: string,
    options: AxiosRequestConfig = {}
  ): Promise<string> {
    const { data } = await this.loadData(url, {
      ...options,
      headers: {
        Accept: 'text/html',
        ...options.headers,
      },
    });
    return data;
  }
}
