# Youthacks Auth OIDC Guide

Use OpenID Connect (OIDC) to sign SPS users in with Youthacks Auth.


## TL;DR

1. Create an OAuth app and get `client_id` + `client_secret`.
2. Discover endpoints from `/.well-known/openid-configuration`.
3. Redirect user to `/oauth/authorize`.
4. Receive `code` on your callback.
5. POST JSON to `/oauth/token` to exchange code.
6. Validate `id_token` using JWKS.
7. Optionally call `/oauth/userinfo`.

## Discovery

Use discovery so SPS does not hardcode endpoint URLs.

- `GET /.well-known/openid-configuration`

This gives you:

- `issuer`
- `authorization_endpoint`
- `token_endpoint`
- `userinfo_endpoint`
- `jwks_uri`
- supported scopes and token auth methods

## Quick Start

### 1. Create an OAuth application

Register SPS as an OAuth client and configure:

- Redirect URI (exact match), for example `https://sps.example.org/auth/callback`
- Client type: confidential

Keep your credentials:

- `client_id`
- `client_secret`

### 2. Redirect users to authorize

Redirect the browser to the discovery `authorization_endpoint`.

Required query params:

- `client_id`
- `redirect_uri`
- `response_type=code`
- `scope=openid profile email`
- `state` (random, per request)
- `nonce` (random, per request)

Example:

```text
https://auth.youthacks.org/oauth/authorize?client_id=sps_client&redirect_uri=https%3A%2F%2Fsps.example.org%2Fauth%2Fcallback&response_type=code&scope=openid%20profile%20email&state=RANDOM_STATE&nonce=RANDOM_NONCE
```

### 3. Handle callback

After user authentication, SPS receives:

```text
https://sps.example.org/auth/callback?code=AUTH_CODE&state=RANDOM_STATE
```

Before continuing, SPS must validate `state`.

### 4. Exchange code for tokens (JSON)

SPS should call the public token endpoint with JSON:

- `POST /oauth/token`
- `Content-Type: application/json`

Request body:

```json
{
	"client_id": "sps_client",
	"client_secret": "SPS_CLIENT_SECRET",
	"redirect_uri": "https://sps.example.org/auth/callback",
	"code": "AUTH_CODE",
	"grant_type": "authorization_code"
}
```

Example response:

```json
{
	"access_token": "atk_...",
	"token_type": "Bearer",
	"expires_in": 900,
	"refresh_token": "rtk_...",
	"id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

Note: This public endpoint accepts JSON from SPS and relays internally.

## Validate the ID token

SPS should validate `id_token` (RS256 JWT):

1. Read `kid` from token header.
2. Fetch keys from `jwks_uri`.
3. Verify signature.
4. Verify claims:
- `iss` equals discovery `issuer`
- `aud` contains your `client_id`
- `exp` is valid
- `iat` is sensible
- `nonce` matches the nonce you stored

Use `sub` as the stable account identifier.

## Fetch user info (optional)

If needed, call `userinfo_endpoint` with bearer token:

```bash
curl -X GET "https://auth.youthacks.org/oauth/userinfo" \
	-H "Authorization: Bearer ACCESS_TOKEN"
```

Common claims include:

- `sub`
- `name`
- `given_name`
- `family_name`
- `username`
- `email`

## Scopes and claims

Core scopes currently used by SPS integrations:

- `openid`: required for OIDC (`sub` claim)
- `profile`: profile claims (`name`, `given_name`, `family_name`, `username`)
- `email`: `email`

Recommended default for SPS:

- `openid profile email`

## Refresh token flow (JSON)

When `access_token` expires:

- `POST /oauth/token`
- `Content-Type: application/json`

```json
{
	"grant_type": "refresh_token",
	"refresh_token": "REFRESH_TOKEN",
	"client_id": "sps_client",
	"client_secret": "SPS_CLIENT_SECRET"
}
```

## Reauthentication

To force sign-in again for sensitive actions, include:

- `prompt=login`

Example:

```text
https://auth.youthacks.org/oauth/authorize?client_id=sps_client&redirect_uri=https%3A%2F%2Fsps.example.org%2Fauth%2Fcallback&response_type=code&scope=openid%20profile%20email&state=RANDOM_STATE&nonce=RANDOM_NONCE&prompt=login
```

## Common errors

- `invalid_client`: wrong `client_id` or `client_secret`
- `invalid_grant`: expired/reused code, or redirect URI mismatch
- `unauthorized_client`: client is not allowed for this flow
- `access_denied`: user denied access

## Production checklist

1. Use HTTPS for all callback and auth URLs.
2. Keep `client_secret` server-side only.
3. Generate unique `state` and `nonce` for each auth request.
4. Validate `state`, `nonce`, and ID token claims.
5. Use exact redirect URI matching.
6. Do not log raw access/refresh/ID tokens.

## Library integrations

Any standard OIDC client library should work via discovery.

Common choices:

- Node.js: `openid-client`
- Ruby: `omniauth-openid-connect`
- Python: `Authlib`
- Go: `go-oidc`

Point your library to:

- `https://<your-auth-domain>/.well-known/openid-configuration`