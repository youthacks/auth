import type { APIRoute } from 'astro';

export const prerender = false;

const backendBaseUrl = (import.meta.env.BACKEND_URL || 'http://localhost:3000').replace(/\/$/, '');
const jwksEndpoint = `${backendBaseUrl}/oauth/discovery/keys`;

export const GET: APIRoute = async () => {
  const upstream = await fetch(jwksEndpoint, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
    },
  });

  const responseHeaders = new Headers();
  const upstreamType = upstream.headers.get('content-type');
  if (upstreamType) {
    responseHeaders.set('Content-Type', upstreamType);
  }

  const cacheControl = upstream.headers.get('cache-control');
  if (cacheControl) {
    responseHeaders.set('Cache-Control', cacheControl);
  }

  return new Response(await upstream.text(), {
    status: upstream.status,
    headers: responseHeaders,
  });
};
