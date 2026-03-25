import type { APIRoute } from 'astro';

export const prerender = false;

const env = (import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env || {};
const backendBaseUrl = (env.BACKEND_URL || 'http://localhost:3000').replace(/\/$/, '');
const discoveryEndpoint = `${backendBaseUrl}/.well-known/openid-configuration`;

const ENDPOINT_KEYS = [
  'authorization_endpoint',
  'token_endpoint',
  'userinfo_endpoint',
  'jwks_uri',
  'end_session_endpoint',
  'registration_endpoint',
  'introspection_endpoint',
  'revocation_endpoint',
  'check_session_iframe',
] as const;

const rewriteEndpointOrigin = (value: unknown, targetOrigin: string): unknown => {
  if (typeof value !== 'string' || value.length === 0) {
    return value;
  }

  try {
    const parsed = new URL(value);
    return `${targetOrigin}${parsed.pathname}${parsed.search}`;
  } catch {
    return value;
  }
};

export const GET: APIRoute = async ({ request }) => {
  const configuredFrontend = (env.FRONTEND_URL || '').replace(/\/$/, '');
  const publicOrigin = configuredFrontend || new URL(request.url).origin;

  const upstream = await fetch(discoveryEndpoint, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
    },
  });

  if (!upstream.ok) {
    return new Response(JSON.stringify({
      error: 'discovery_unavailable',
      error_description: 'Could not load OpenID configuration from backend',
    }), {
      status: 502,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    });
  }

  let discovery: Record<string, unknown>;
  try {
    discovery = await upstream.json();
  } catch {
    return new Response(JSON.stringify({
      error: 'invalid_discovery_response',
      error_description: 'Backend discovery endpoint returned invalid JSON',
    }), {
      status: 502,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    });
  }

  const proxiedDiscovery: Record<string, unknown> = { ...discovery };
  for (const key of ENDPOINT_KEYS) {
    proxiedDiscovery[key] = rewriteEndpointOrigin(discovery[key], publicOrigin);
  }

  return new Response(JSON.stringify(proxiedDiscovery), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=300',
    },
  });
};
