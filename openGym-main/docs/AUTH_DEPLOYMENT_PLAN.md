# Account security and deployment plan

## Current state

The React client uses same-origin /api calls. Passkey registration and sign-in, optional password sign-in and admin reset codes, signed cookies, CSRF checks, per-address password throttling, account-scoped data routes, and guest-local data already exist. Guest data is held on the device until an authenticated sync succeeds. Ordinary logout now persists a hash of the revoked token; sign-out everywhere increments the account session version.

The Vercel project currently routes /api to a Node service, but this API stores its secret, db.json, state files, uploads, and audit logs under DATA_DIR. On Vercel it defaults to /tmp/data. A writable temporary directory is not durable or shared across function instances. /api/health reporting writable: true does not establish persistence. Registrations there could disappear while cookies and passkeys outlive their server-side records.

## Implementation sequence

1. Fail startup when the file-backed API detects Vercel. Keep Vercel as a frontend host only until the API has durable shared storage.
2. Make registration and sign-in messages describe the result accurately. A completed account creation or sign-in must not be reported as failed merely because the later data sync failed. Only report guest data as moved after the server confirms the push.
3. Keep the existing WebAuthn, optional password, admin-issued recovery, guest-data adoption, and logout flows. Add focused tests for the storage guard, individual session revocation, and the split between authentication and synchronization results. Redact invite codes from audit entries. Run the existing API and frontend auth tests. Password reset requires an admin-issued code; the optional e-mail is a sign-in identifier, not an e-mail recovery channel. A passkey-only profile needs another enrolled passkey or a signed-in device to add one; there is no automatic recovery if all authenticators are lost.
4. Provision a durable backend before enabling live accounts. The existing Docker Compose stack on a VM with a persistent ./data volume is the smallest change to the code. Run one API process: WebAuthn challenges and rate-limit counters are currently in process memory, so multiple replicas would require a shared challenge and throttle store. Back up data/ off the VM and test a restore. Keep the API and frontend under one HTTPS origin so ORIGIN, RP_ID, CSRF checks, and host-only cookies agree. If the frontend remains on Vercel, proxy /api/* to that VM under the frontend origin; validate the full request path and cookie behavior before public signup.
5. Configure ORIGIN to the exact public HTTPS origin and RP_ID to its hostname. Set FIRST_USER_ADMIN, INVITE_ONLY, PASSWORD_LOGIN, and TRUST_PROXY only after reviewing the deployment. Set TRUST_PROXY only when the reverse proxy overwrites forwarding headers. Store no secrets in client builds or source control.
6. Test a real browser on the final origin: create a passkey profile, sign out and in, create a second profile, reject cross-account reads and writes, reject reused and expired challenges, exercise optional password and reset-code flows if enabled, and verify guest-data migration and recovery after a backend restart. Confirm the public hostname equals RP_ID and ORIGIN is its full HTTPS origin. Confirm session revocation, backups, and restore. The currently supplied Vercel URL could not be resolved during the final live check, so live RP ID and origin remain unverified.
7. Deploy only after durable storage and the end-to-end checks above are complete. Oracle Cloud Always Free is a possible zero-monthly-cost VM, subject to account verification, capacity, and service limits. Do not assume it is provisioned merely because the Vercel API answers.

## Release gate

No production auth deployment until there is a configured persistent backend, a backup and restore test, and a passing end-to-end account test on the intended HTTPS origin.
