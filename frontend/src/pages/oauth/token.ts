import type { APIRoute } from 'astro';

export const prerender = false;

const backendBaseUrl = (import.meta.env.BACKEND_URL || 'http://localhost:3000').replace(/\/$/, '');
const tokenEndpoint = `${backendBaseUrl}/v1/oidc/token`;

export const POST: APIRoute = async ({ request }) => {
  const contentType = request.headers.get('content-type') || 'application/json';
  const body = await request.text();

  const headers = new Headers({
    Accept: 'application/json',
    'Content-Type': contentType,
  });

  const authorization = request.headers.get('authorization');
  if (authorization) {
    headers.set('Authorization', authorization);
  }

  const upstream = await fetch(tokenEndpoint, {
    method: 'POST',
    headers,
    body,
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
