// IP Registration Worker for Cloudflare Access
// Captures visitor's public IP after Access OTP auth,
// adds it to an Access policy's include rules, and stores in KV with TTL.

const TTL_DAYS = 45;
const TTL_SECONDS = TTL_DAYS * 24 * 60 * 60;

export default {
  async fetch(request, env) {
    const ip = request.headers.get("CF-Connecting-IP");
    const email = request.headers.get("Cf-Access-Authenticated-User-Email") || "unknown";

    if (request.method === "POST") {
      try {
        await env.IP_KV.put(`ip:${email}`, ip, { expirationTtl: TTL_SECONDS });
        await rebuildPolicy(env);
        return htmlResponse(200, ip, email, "registered", TTL_DAYS);
      } catch (err) {
        return htmlResponse(500, ip, email, "error: " + err.message, 0);
      }
    }

    try {
      const registeredIp = await env.IP_KV.get(`ip:${email}`);
      const status = registeredIp === ip ? "active" : registeredIp ? "different" : "not registered";
      return htmlResponse(200, ip, email, status, TTL_DAYS, registeredIp);
    } catch (err) {
      return htmlResponse(500, ip, email, "error: " + err.message, 0);
    }
  },

  async scheduled(event, env) {
    // Refresh TTLs for IPs that actively accessed Jellyfin in the last 24h
    await refreshActiveIps(env);
    // Rebuild policy from surviving KV entries (expired ones auto-deleted)
    await rebuildPolicy(env);
  }
};

async function refreshActiveIps(env) {
  // Query Access audit logs for media.8devops.com requests in the last 24h
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${env.ACCOUNT_ID}/access/logs/access_requests?direction=desc&limit=1000&since=${since}`,
    {
      headers: { Authorization: `Bearer ${env.CF_API_TOKEN}` }
    }
  );

  if (!res.ok) return;
  const data = await res.json();
  if (!data.success || !data.result) return;

  // Collect unique IPs that accessed Jellyfin
  const activeIps = new Set();
  for (const entry of data.result) {
    if (entry.ip_address) {
      activeIps.add(entry.ip_address);
    }
  }

  // Refresh TTL for any registered IP that was active
  const keys = await env.IP_KV.list({ prefix: "ip:" });
  for (const key of keys.keys) {
    const registeredIp = await env.IP_KV.get(key.name);
    if (registeredIp && activeIps.has(registeredIp)) {
      await env.IP_KV.put(key.name, registeredIp, { expirationTtl: TTL_SECONDS });
    }
  }
}

async function rebuildPolicy(env) {
  // Read all surviving KV entries
  const keys = await env.IP_KV.list({ prefix: "ip:" });
  const includeRules = [];

  for (const key of keys.keys) {
    const ip = await env.IP_KV.get(key.name);
    if (ip) {
      includeRules.push({ ip: { ip: ip + "/32" } });
    }
  }

  // Must have at least one include rule; use placeholder if empty
  if (includeRules.length === 0) {
    includeRules.push({ ip: { ip: "198.51.100.1/32" } });
  }

  // Update the Family IPs policy
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${env.ACCOUNT_ID}/access/apps/${env.MEDIA_APP_ID}/policies/${env.FAMILY_POLICY_ID}`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${env.CF_API_TOKEN}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        name: "Family IPs",
        decision: "allow",
        include: includeRules,
        precedence: 2
      })
    }
  );

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Failed to update policy: ${err}`);
  }
}

function htmlResponse(status, ip, email, state, ttlDays, registeredIp) {
  const stateMessages = {
    "active": `Your IP <strong>${ip}</strong> is registered. Access expires in ${ttlDays} days.`,
    "different": `Your current IP is <strong>${ip}</strong> but <strong>${registeredIp}</strong> is registered. Click Register to update.`,
    "not registered": `Your IP <strong>${ip}</strong> is not registered.`,
    "registered": `Your IP <strong>${ip}</strong> has been registered for ${ttlDays} days.`
  };

  const message = state.startsWith("error") ? `Error: ${state}` : (stateMessages[state] || state);
  const showButton = state !== "active" && state !== "registered";

  const html = `<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Jellyfin Access Registration</title>
  <style>
    body { font-family: -apple-system, sans-serif; max-width: 480px; margin: 60px auto; padding: 0 20px; background: #1a1a2e; color: #e0e0e0; }
    .card { background: #16213e; border-radius: 12px; padding: 32px; box-shadow: 0 4px 24px rgba(0,0,0,0.3); }
    h1 { margin: 0 0 8px; font-size: 22px; color: #00d4aa; }
    .email { color: #888; font-size: 14px; margin-bottom: 24px; }
    .status { font-size: 16px; line-height: 1.6; margin-bottom: 24px; }
    form { margin: 0; }
    button { background: #00d4aa; color: #1a1a2e; border: none; padding: 14px 32px; border-radius: 8px; font-size: 16px; font-weight: 600; cursor: pointer; width: 100%; }
    button:hover { background: #00b894; }
    .success { color: #00d4aa; }
    .redirect { margin-top: 16px; font-size: 14px; color: #888; }
    .redirect a { color: #00d4aa; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Jellyfin Access</h1>
    <div class="email">${email}</div>
    <div class="status ${state === "registered" ? "success" : ""}">${message}</div>
    ${showButton ? '<form method="POST"><button type="submit">Register My IP</button></form>' : ''}
    ${state === "registered" ? '<div class="redirect"><a href="https://media.8devops.com">Go to Jellyfin</a></div>' : ''}
  </div>
</body>
</html>`;

  return new Response(html, {
    status,
    headers: { "Content-Type": "text/html;charset=UTF-8" }
  });
}
