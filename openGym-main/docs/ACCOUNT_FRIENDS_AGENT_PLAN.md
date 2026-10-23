# Lifting Life: account and friends improvement plan

The goal is an honest, professional experience: a button reports success only after the server confirms it, guest workouts remain recoverable if sync fails, and the Friends screen shows real relationships rather than sample athletes presented as live users.

## Agent 1 — accounts

**Prompt:** Trace registration, passkey and optional password login, logout, recovery, and guest-data adoption through `frontend/src/views/Login.jsx`, `frontend/src/components/PasswordAuth.jsx`, `frontend/src/lib/api.js`, `frontend/src/store/useStore.js`, and the account routes in `api/server.js`. Improve the wording, accessibility, loading and error states, and safe recovery instructions. Preserve the one-time WebAuthn challenge, exact HTTPS origin/RP ID, CSRF protection, throttling, per-user authorization, and server-side session revocation. Never present a failed sync as a failed registration or a successful data transfer. Add tests for success, duplicate signup, wrong credentials, expired challenges, lost network access, logout, and recovery. Do not deploy.

**Acceptance:** A guest can create an account without losing local workouts; the UI says clearly whether workouts reached the server. Password recovery says it requires an admin-issued code, and passkey-only users are told how to avoid lockout. A signed-out token cannot read account data. All account actions have clear pending, success, and failure states.

## Agent 2 — friends

**Prompt:** Replace the Community screen's pretend friend requests, athletes, posts, and circles with a truthful Friends experience. Implement authenticated, account-scoped friend requests and relationships on the durable backend: a private, one-use shareable friend code, request, incoming/outgoing lists, accept, decline, cancel, and remove. Prevent self-requests, duplicate relationships, unauthorized decisions, and broad account enumeration. Rate-limit invitations and requests. Show useful empty and offline states; do not imply workouts or profiles are shared until explicit sharing exists. Keep guest users' local data separate. Add API and UI tests. Do not deploy.

**Acceptance:** Two real test accounts can connect, each sees the correct request state, and a third account cannot approve or remove their relationship. Repeated requests are handled predictably. An offline or failed operation does not display success, and the screen contains no fictitious live activity.

## Integration and release gate

The agents work in separate frontend areas. Agent 2 owns the isolated friend-route block and friend data in `api/server.js`; Agent 1 coordinates before editing that file. Review their combined changes, run focused and production-build checks, and compare failures with the existing broader suite. Keep the live Vercel deployment unchanged until a persistent backend, backups and restore test, final HTTPS `ORIGIN`/`RP_ID`, and real-browser end-to-end account and friend tests all pass. See `AUTH_DEPLOYMENT_PLAN.md` for the durable-storage path and cost limits.

## Implementation result (2026-10-23)

- Account responses must contain a valid user and a matching authenticated `/api/me` result before local account ownership changes. Registration, sign-in, recovery, guest storage, and failed-sync messages now distinguish their actual outcomes; passkey buttons guard against repeated submissions.
- Friends use authenticated 144-bit, one-use, 24-hour codes. Requests and relationships live in the account database, with participant-only mutations and per-account rate limits. The UI renders server-confirmed names and status only; fictional people, posts, circles, and sharing claims were removed.
- Combined focused verification passed: 72 API tests and 72 frontend tests. The production frontend build passed. No deployment was made. The durable backend and final live-origin checks remain release blockers.
