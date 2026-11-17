# Demeisen Auth

One sign-in for all Demeisen sites: sign in once (password plus authenticator-app code) and you're signed in to
the CRM, the intranet and future apps. Built on AWS Cognito, using standard OpenID Connect, so an app can also use
another provider (Microsoft Entra ID, Okta, Google) by changing settings only.

Nothing in this repo is specific to Demeisen: no user lists, passwords, account numbers or addresses. It can be
shared with other organisations as it is.

## Contents

- `cognito/user-pool.yaml`: creates a sign-in (Cognito user pool) for invited users only, with an authenticator-app
  code required and a 14-character password policy. Only needed for a new organisation.
- `cognito/app-client.yaml`: registers one app with an existing user pool. One stack per app.
- `python/demeisen_auth.py`: sign-in for Flask apps (single file; needs `PyJWT[crypto]`). Adds `/auth/login`,
  `/auth/callback`, `/auth/logout`; `auth.email()` returns the signed-in person's verified email.
  Each app decides what that person may do (e.g. the intranet only admits people in its own user list).

## Adding an app

1. Register it:
   ```
   aws cloudformation deploy --template-file cognito/app-client.yaml --stack-name <app>-signin \
     --parameter-overrides UserPoolId=<pool id> AppName=<app> BaseUrl=https://<app address>
   ```
2. Read the client's ID and secret (`aws cognito-idp describe-user-pool-client`) and give the app:
   `OIDC_ISSUER=https://cognito-idp.<region>.amazonaws.com/<pool id>`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`,
   `PUBLIC_URL=https://<app address>`, `OIDC_LOGOUT_URL=https://<domain>.auth.<region>.amazoncognito.com/logout`.
3. Copy `python/demeisen_auth.py` into the app (each app keeps its own copy) and create `OIDC(app, ...)`.

Single-page apps (like the CRM) use the user pool directly from the browser with a public client and an
API Gateway JWT authorizer; they don't need the Python file.

## Inviting and removing people

Invite: Cognito console → user pool → Users → Create user (send an email invitation). Remove access to everything:
disable or delete the user there. Each app can additionally restrict who it admits.

## Current Demeisen set-up (v2)

- `pool/demeisen-pool.yaml`: Demeisen's own user pool, stack `demeisen-v2-auth-pool`. The pool is data (people and
  their authenticator enrolment), so it and its sign-in domain are kept if the stack is deleted, deletion protection
  is on, and `pool/stack-policy.json` blocks any update that would replace or delete them. `tools/check-guardrails.py`
  fails CI if any of that is removed.
- The pool already exists (`eu-west-2_o84PDILyl`, created by the v1 CRM stack). It is adopted into
  `demeisen-v2-auth-pool` with `pool/import.sh` at cut-over, without touching any user. Until then v1 holds it, with
  `DeletionPolicy: Retain` added so that removing v1 can never delete it.
- `pool/refs.yaml` (stack `demeisen-v2-auth-refs`): SSM parameters `/demeisen/v2/auth/user-pool-id`, `issuer` and
  `domain`. Apps read these rather than a CloudFormation export, so nothing locks the pool in place.
- Apps register their own clients: the CRM (browser, public client) in its app stack, the platform (server,
  confidential client) in its app stack.
- Changes to the pool run only from the **Deploy pool** workflow, after approval in the GitHub `data` environment.
