import type { APIRoute } from 'astro';

export const prerender = false;

const backendBaseUrl = (import.meta.env.BACKEND_URL || 'http://localhost:3000').replace(/\/$/, '');
const userinfoEndpoint = `${backendBaseUrl}/oauth/userinfo`;

const proxyUserinfo: APIRoute = async ({ request }) => {
  const contentType = request.headers.get('content-type');
  const body = request.method === 'POST' ? await request.text() : undefined;

  const headers = new Headers({
    Accept: 'application/json',
  });

  if (contentType) {
    headers.set('Content-Type', contentType);
  }

  const authorization = request.headers.get('authorization');
  if (authorization) {
    headers.set('Authorization', authorization);
  }

  const upstream = await fetch(userinfoEndpoint, {
    method: request.method,
    headers,
    body,
  });

  const responseHeaders = new Headers();
  const upstreamType = upstream.headers.get('content-type');
  if (upstreamType) {
    responseHeaders.set('Content-Type', upstreamType);
  }

  return new Response(await upstream.text(), {
    status: upstream.status,
    headers: responseHeaders,
  });
};

export const GET = proxyUserinfo;
export const POST = proxyUserinfo;
