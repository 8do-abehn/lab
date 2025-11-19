# Adding Services to STTS Web

This guide explains how to add new services to STTS Web.

## Quick Reference

Most services use **StatusPage.io** and can be added in under a minute by just editing the JSON configuration file.

## Method 1: Automatic Detection (Recommended)

Use the included Ruby script to automatically detect service details:

```bash
cd scripts
bundle install
bundle exec ruby extract.rb https://status.example.com/
```

The script will output service configuration that you can copy directly into `backend/src/config/services.json`.

### Example Output:
```ruby
{
  id: "example",
  name: "Example Service",
  url: "https://status.example.com",
  type: "statuspage",
  statusPageID: "abc123xyz",
  domain: "statuspage.io"
}
```

## Method 2: Manual Addition

### For StatusPage.io Services (Most Common)

StatusPage.io is used by GitHub, Stripe, Heroku, Cloudflare, and 100+ other services.

**Step 1**: Identify if the service uses StatusPage.io

Visit the status page and check:
- Look for "Powered by StatusPage" in the footer
- Check if the URL contains `statuspage.io`
- Look at the page source for StatusPage identifiers

**Step 2**: Find the Status Page ID

Method A - From the URL:
```
https://kctbh9vrtdwd.statuspage.io/  ← Status Page ID is "kctbh9vrtdwd"
```

Method B - From the HTML source:
```html
<meta name="page-id" content="kctbh9vrtdwd">
```

Method C - From the API URL:
```
https://kctbh9vrtdwd.statuspage.io/api/v2/summary.json
```

**Step 3**: Add to `backend/src/config/services.json`:

```json
{
  "id": "github",
  "name": "GitHub",
  "url": "https://www.githubstatus.com",
  "type": "statuspage",
  "statusPageID": "kctbh9vrtdwd",
  "domain": "statuspage.io"
}
```

### For Custom Domain StatusPage Services

Some services host StatusPage on their own domain (e.g., Heroku, npm):

```json
{
  "id": "heroku",
  "name": "Heroku",
  "url": "https://status.heroku.com",
  "type": "statuspage",
  "statusPageID": "status",
  "domain": "heroku.com"
}
```

The API URL will be: `https://status.heroku.com/api/v2/summary.json`

## Method 3: Custom Service Implementation

For services that don't use StatusPage.io, you'll need to create a custom implementation.

### Step 1: Analyze the Status Page

Visit the status page and determine:
1. Does it have a JSON API?
2. Do we need to parse HTML?
3. What status states does it have?

### Step 2: Create a Service Class

Create a new file in `backend/src/services/custom/YourService.ts`:

```typescript
import { BaseService, ServiceStatus } from '../base/Service';
import { HttpClient } from '../base/HttpClient';

export class YourService extends BaseService {
  async updateStatus(): Promise<void> {
    try {
      // Option A: JSON API
      const data = await HttpClient.loadJSON<any>(this.config.apiUrl);
      const status = this.parseStatus(data.status);

      // Option B: HTML Parsing
      const html = await HttpClient.loadHTML(this.config.url);
      const $ = cheerio.load(html);
      const statusText = $('#status').text();

      // Set the status
      this.statusDescription = {
        status: status,
        message: data.message || 'All systems operational',
      };
    } catch (error) {
      this.fail(error as Error);
    }
  }

  private parseStatus(statusString: string): ServiceStatus {
    // Map the service's status to our ServiceStatus enum
    switch (statusString.toLowerCase()) {
      case 'operational':
      case 'ok':
        return ServiceStatus.Good;
      case 'degraded':
        return ServiceStatus.Minor;
      case 'outage':
        return ServiceStatus.Major;
      case 'maintenance':
        return ServiceStatus.Maintenance;
      default:
        return ServiceStatus.Undetermined;
    }
  }
}
```

### Step 3: Register the Service Type

Edit `backend/src/services/ServiceFactory.ts`:

```typescript
import { YourService } from './custom/YourService';

// In the serviceTypes Map:
private static serviceTypes: Map<...> = new Map([
  ['statuspage', StatusPageService],
  ['slack', SlackService],
  ['yourservice', YourService],  // Add this line
]);
```

### Step 4: Add Configuration

Add to `backend/src/config/services.json`:

```json
{
  "id": "yourservice",
  "name": "Your Service",
  "url": "https://status.yourservice.com",
  "type": "yourservice",
  "apiUrl": "https://api.yourservice.com/status"
}
```

## Testing New Services

1. **Add the service configuration**
2. **Restart the backend server**:
   ```bash
   cd backend
   npm run dev
   ```
3. **Check the logs** for any errors
4. **Test the API endpoint**:
   ```bash
   curl http://localhost:3001/api/services/yourservice
   ```
5. **View in the frontend** at http://localhost:3000

## Common Patterns

### Pattern 1: StatusPage.io (80% of services)
```json
{
  "type": "statuspage",
  "statusPageID": "...",
  "domain": "statuspage.io"
}
```

### Pattern 2: JSON API
```typescript
const data = await HttpClient.loadJSON<ApiResponse>(apiUrl);
const status = this.mapToStatus(data.status);
```

### Pattern 3: HTML Parsing
```typescript
const html = await HttpClient.loadHTML(this.config.url);
const $ = cheerio.load(html);
const status = $('.status-indicator').attr('data-status');
```

### Pattern 4: RSS/Atom Feeds
```typescript
// Parse XML feed for incidents
```

## Converting from Original STTS

If you're converting a service from the original Swift app:

1. **Find the Swift file** (e.g., `Services/GitHub.swift`)
2. **Check what it extends**:
   - `StatusPageService` → Just add JSON config
   - `StatusioV1Service` → Need to implement Status.io v1 checker
   - `InstatusService` → Need to implement Instatus checker
   - Custom class → Need custom implementation

3. **Extract the required properties**:
   ```swift
   // Swift:
   let url = URL(string: "https://status.github.com")!
   let statusPageID = "kctbh9vrtdwd"

   // Becomes JSON:
   {
     "url": "https://status.github.com",
     "statusPageID": "kctbh9vrtdwd"
   }
   ```

## Bulk Adding Services

To add multiple services at once:

1. Create a script that calls `extract.rb` for each URL
2. Collect all the outputs
3. Format as JSON array
4. Add to `services.json`

Example bash script:
```bash
#!/bin/bash
urls=(
  "https://status.github.com"
  "https://status.gitlab.com"
  "https://status.stripe.com"
)

for url in "${urls[@]}"; do
  echo "Extracting $url..."
  bundle exec ruby extract.rb "$url"
done
```

## Service Definition Reference

### Required Fields
- `id`: Unique identifier (lowercase, no spaces)
- `name`: Display name
- `url`: Status page URL
- `type`: Service type (e.g., "statuspage", "slack")

### Optional Fields (depends on type)
- `statusPageID`: For StatusPage.io services
- `domain`: For custom domain StatusPage services
- `apiUrl`: For custom API endpoints
- Any custom fields your service implementation needs

## Troubleshooting

### Service shows "Undetermined" status
- Check if the API endpoint is accessible
- Verify the statusPageID is correct
- Check backend logs for errors

### Service not appearing
- Verify JSON syntax in services.json
- Check the `id` is unique
- Restart the backend server

### "Unknown service type" error
- Verify the service type is registered in ServiceFactory
- Check spelling of the type name
- Ensure the service class is imported

## Need Help?

- Check the original stts repository for examples
- Look at existing service implementations in `backend/src/services/`
- Test API endpoints directly in your browser or with curl
