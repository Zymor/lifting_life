import test from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/server.js';
import { computeTotp, verifyTotp } from '../src/security.js';
import { db } from '../src/db.js';

const app = createApp();

// Helper to make mock HTTP requests against Express app
async function request(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, '127.0.0.1', async () => {
      const port = server.address().port;
      try {
        const url = `http://127.0.0.1:${port}${path}`;
        const options = {
          method,
          headers: {
            'Content-Type': 'application/json',
            ...headers
          }
        };
        if (body && ['POST', 'PUT', 'PATCH'].includes(method)) {
          options.body = JSON.stringify(body);
        }
        const res = await fetch(url, options);
        const data = await res.json().catch(() => null);
        server.close();
        resolve({ status: res.status, headers: res.headers, data });
      } catch (err) {
        server.close();
        reject(err);
      }
    });
  });
}

test('1. Public Health Check responds with status ok', async () => {
  const res = await request('GET', '/api/health');
  assert.equal(res.status, 200);
  assert.equal(res.data.status, 'ok');
});

test('2. Real User Registration & Email Verification Flow', async () => {
  const email = `test.lifter.${Date.now()}@example.com`;
  const regRes = await request('POST', '/api/auth/register', {
    email,
    password: 'ValidPassword123!',
    username: `lifter_${Date.now()}`
  });
  assert.equal(regRes.status, 201);
  assert.equal(regRes.data.requiresVerification, true);
  const code = regRes.data.verificationCodeDev;
  assert.ok(code);

  // Wrong code is rejected
  const wrongRes = await request('POST', '/api/auth/verify-email', {
    email,
    code: '000000'
  });
  assert.equal(wrongRes.status, 400);

  // Correct code confirms account and creates session
  const verifyRes = await request('POST', '/api/auth/verify-email', {
    email,
    code
  });
  assert.equal(verifyRes.status, 200);
  assert.ok(verifyRes.data.token);
  assert.equal(verifyRes.data.user.emailVerified, true);

  // User can now log in
  const loginRes = await request('POST', '/api/auth/login', {
    email,
    password: 'ValidPassword123!'
  });
  assert.equal(loginRes.status, 200);
  assert.ok(loginRes.data.token);
  assert.equal(loginRes.data.user.email, email);

  // Incorrect password fails
  const badLogin = await request('POST', '/api/auth/login', {
    email,
    password: 'WrongPassword!'
  });
  assert.equal(badLogin.status, 401);
});

test('3. Admin Authentication requires MFA and blocks ordinary users', async () => {
  // Step A: Attempt admin login with valid super admin credentials
  const loginRes = await request('POST', '/api/admin/auth/login', {
    email: 'admin@liftinglife.com',
    password: 'SuperAdminKey2026!'
  });
  assert.equal(loginRes.status, 200);
  assert.equal(loginRes.data.requiresMfa, true);
  const challengeToken = loginRes.data.challengeToken;
  assert.ok(challengeToken);

  // Retrieve admin MFA secret from DB
  const mfa = db.prepare(`
    SELECT m.totp_secret
    FROM admin_mfa m
    JOIN users u ON u.id = m.user_id
    WHERE u.email = 'admin@liftinglife.com'
  `).get();
  assert.ok(mfa && mfa.totp_secret);

  // Generate live TOTP code
  const totpCode = computeTotp(mfa.totp_secret);

  // Step B: Verify MFA
  const mfaRes = await request('POST', '/api/admin/auth/verify-mfa', {
    challengeToken,
    code: totpCode
  });
  assert.equal(mfaRes.status, 200);
  const adminToken = mfaRes.data.token;
  assert.ok(adminToken);

  // Step C: Access protected Admin API
  const statsRes = await request('GET', '/api/admin/stats', null, {
    'Authorization': `Bearer ${adminToken}`
  });
  assert.equal(statsRes.status, 200);
  assert.ok(statsRes.data.kpis.totalExercises >= 5000);
  assert.equal(statsRes.data.kpis.systemStatus, 'Operational');

  // Step D: Ordinary user cannot access Admin API
  const userReg = await request('POST', '/api/auth/register', {
    email: `ordinary.${Date.now()}@example.com`,
    password: 'StrongUser123!',
    username: `user_${Date.now()}`
  });
  const userVerify = await request('POST', '/api/auth/verify-email', {
    email: userReg.data.email,
    code: userReg.data.verificationCodeDev
  });
  const userToken = userVerify.data.token;

  const deniedRes = await request('GET', '/api/admin/stats', null, {
    'Authorization': `Bearer ${userToken}`
  });
  assert.equal(deniedRes.status, 403);
});

test('4. Admin User Management: Suspension and Audit Logging', async () => {
  // 1. Authenticate Admin
  const loginRes = await request('POST', '/api/admin/auth/login', {
    email: 'admin@liftinglife.com',
    password: 'SuperAdminKey2026!'
  });
  const mfa = db.prepare('SELECT totp_secret FROM admin_mfa WHERE user_id = ?').get(loginRes.data.user.id);
  const mfaRes = await request('POST', '/api/admin/auth/verify-mfa', {
    challengeToken: loginRes.data.challengeToken,
    code: computeTotp(mfa.totp_secret)
  });
  const adminToken = mfaRes.data.token;

  // 2. Create a test user to suspend
  const email = `suspend.me.${Date.now()}@example.com`;
  const reg = await request('POST', '/api/auth/register', {
    email,
    password: 'UserToSuspend123!',
    username: `suspend_${Date.now()}`
  });
  const verified = await request('POST', '/api/auth/verify-email', {
    email,
    code: reg.data.verificationCodeDev
  });
  const targetUserId = verified.data.user.id;

  // 3. Suspend Account
  const suspendRes = await request('PATCH', `/api/admin/users/${targetUserId}/status`, {
    status: 'suspended',
    reason: 'Terms of service violation'
  }, { 'Authorization': `Bearer ${adminToken}` });
  assert.equal(suspendRes.status, 200);
  assert.equal(suspendRes.data.user.status, 'suspended');

  // 4. Verify suspended user login is blocked
  const blockedLogin = await request('POST', '/api/auth/login', {
    email,
    password: 'UserToSuspend123!'
  });
  assert.equal(blockedLogin.status, 403);

  // 5. Verify audit log was recorded
  const auditRes = await request('GET', '/api/admin/audit-logs?action=user_suspend', null, {
    'Authorization': `Bearer ${adminToken}`
  });
  assert.equal(auditRes.status, 200);
  assert.ok(auditRes.data.logs.some(l => l.target_id === targetUserId));
});

test('5. Exercise Library Management: CRUD, Duplicates, and Public Sync', async () => {
  const loginRes = await request('POST', '/api/admin/auth/login', {
    email: 'admin@liftinglife.com',
    password: 'SuperAdminKey2026!'
  });
  const mfa = db.prepare('SELECT totp_secret FROM admin_mfa WHERE user_id = ?').get(loginRes.data.user.id);
  const mfaRes = await request('POST', '/api/admin/auth/verify-mfa', {
    challengeToken: loginRes.data.challengeToken,
    code: computeTotp(mfa.totp_secret)
  });
  const adminToken = mfaRes.data.token;

  // Create new exercise
  const testExName = `Custom Incline Plate Press ${Date.now()}`;
  const createRes = await request('POST', '/api/admin/exercises', {
    name: testExName,
    category: 'Chest',
    equipment: 'Plate Loaded',
    primaryMuscle: 'Pectoralis Major',
    difficulty: 'Intermediate',
    instructions: ['Set bench angle to 30 degrees', 'Drive elbows together at contraction'],
    description: 'High chest isolation movement.'
  }, { 'Authorization': `Bearer ${adminToken}` });
  assert.equal(createRes.status, 201);
  const exId = createRes.data.id;

  // Duplicate name check
  const dupRes = await request('POST', '/api/admin/exercises', {
    name: testExName,
    category: 'Chest',
    equipment: 'Plate Loaded',
    primaryMuscle: 'Chest'
  }, { 'Authorization': `Bearer ${adminToken}` });
  assert.equal(dupRes.status, 409);

  // Update exercise
  const updateRes = await request('PUT', `/api/admin/exercises/${exId}`, {
    suggestedSets: 4,
    suggestedReps: '10-12',
    description: 'Updated technique instructions.'
  }, { 'Authorization': `Bearer ${adminToken}` });
  assert.equal(updateRes.status, 200);

  // Public endpoint reflects newly created exercise
  const publicRes = await request('GET', `/api/public/exercises?search=${encodeURIComponent(testExName)}`);
  assert.equal(publicRes.status, 200);
  assert.equal(publicRes.data.exercises.length, 1);
  assert.equal(publicRes.data.exercises[0].name, testExName);
});

