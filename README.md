# Youthacks Auth

Youthacks authentication system for hackathon tools: a single Ruby on Rails app that
handles sign-up with email verification, sign-in, and acts as an OAuth 2.0 / OpenID
Connect provider for other Youthacks services.

- Rails 8 with server-rendered views (Hotwire Turbo + Stimulus for the little JS there is)
- JavaScript bundled with **esbuild**, CSS built with **Tailwind CSS v4**, both run through npm
  and served by Propshaft
- PostgreSQL, Doorkeeper + doorkeeper-openid_connect for OAuth/OIDC

## OAuth / OIDC documentation

For the full OAuth 2.0 + OpenID Connect flow for integrating apps, see [OAUTH_FLOW.md](OAUTH_FLOW.md).

## Running locally

Requirements: Ruby (see `.ruby-version`), Node.js 20+, PostgreSQL.

```sh
bundle install
npm install
cp .env.example .env   # then edit DATABASE_URL etc.
bin/rails db:prepare
bin/dev                # Rails server + esbuild + Tailwind watchers on http://localhost:3000
```

`bin/dev` uses `foreman` to run the three processes in `Procfile.dev`. To run just the
server after a one-off asset build:

```sh
npm run build && npm run build:css
bin/rails server
```

### Environment variables

| Variable          | Purpose                                                                 |
| ----------------- | ----------------------------------------------------------------------- |
| `APP_URL`         | Public URL of this app; used as the OIDC `issuer` and for mailer links. |
| `DATABASE_URL`    | PostgreSQL connection string.                                            |
| `SECRET_KEY_BASE` | Rails secret (production).                                               |
| `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` | Outgoing mail for verification codes. |

The OIDC signing key lives in the encrypted credentials under `doorkeeper.oidc.signing_key`.

### Making yourself an admin

Admins manage OAuth clients at `/admin/clients`. Flip the flag from a console:

```sh
bin/rails runner 'User.find_by!(username: "yourname").update!(admin: true)'
```

## Tests

```sh
bin/rails test
```

## Deployment

The `Dockerfile` builds a production image (installs Node only in the build stage, runs
`assets:precompile`, then ships a slim runtime image). `config/deploy.yml` is a Kamal
configuration you can adapt. Set `APP_URL`, `DATABASE_URL`, `RAILS_MASTER_KEY` and the
`SMTP_*` variables in the production environment.
