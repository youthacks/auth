import type { APIRoute } from 'astro';

export const prerender = false;

export const GET: APIRoute = async ({ request }) => {
  const configuredFrontend = (import.meta.env.FRONTEND_URL || '').replace(/\/$/, '');
  const origin = configuredFrontend || new URL(request.url).origin;

  const discovery = {
    issuer: origin,
    authorization_endpoint: `${origin}/oauth/authorize`,
    token_endpoint: `${origin}/oauth/token`,
    userinfo_endpoint: `${origin}/oauth/userinfo`,
    jwks_uri: `${origin}/oauth/jwks`,
    response_types_supported: ['code'],
    grant_types_supported: ['authorization_code', 'refresh_token'],
    subject_types_supported: ['public'],
    id_token_signing_alg_values_supported: ['RS256'],
    scopes_supported: ['openid', 'profile', 'email'],
    token_endpoint_auth_methods_supported: ['client_secret_basic', 'client_secret_post'],
    claims_supported: ['sub', 'name', 'given_name', 'family_name', 'preferred_username', 'email', 'auth_time', 'iss', 'aud', 'exp', 'iat'],
    code_challenge_methods_supported: ['S256'],
  };

  return new Response(JSON.stringify(discovery), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=300',
    },
  });
};
