import express from 'express';
import crypto from 'node:crypto';
import { db } from '../db.js';
import {
  generateSalt,
  hashPassword,
  verifyPassword,
  generateToken,
  generateSixDigitCode,
  checkRateLimit
} from '../security.js';
import { authenticate } from '../middleware/auth.js';

export const authRouter = express.Router();

// 1. User Registration
authRouter.post('/register', (req, res) => {
  const ip = req.ip || req.socket.remoteAddress;
  const rate = checkRateLimit(`reg_${ip}`, 10, 60000);
  if (!rate.allowed) {
    return res.status(429).json({ error: `Too many registration attempts. Retry in ${rate.retryAfterSeconds}s.` });
  }

  const { email, password, username, displayName } = req.body;
  if (!email || !password || !username) {
    return res.status(400).json({ error: 'Email, password, and username are required.' });
  }

  const cleanEmail = email.trim().toLowerCase();
  const cleanUsername = username.trim();

  // Validate email format
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(cleanEmail)) {
    return res.status(400).json({ error: 'Invalid email address format.' });
  }

  // Validate password strength
  if (password.length < 8) {
    return res.status(400).json({ error: 'Password must be at least 8 characters long.' });
  }

  const existing = db.prepare('SELECT id, email_verified FROM users WHERE email = ?').get(cleanEmail);
  if (existing && existing.email_verified === 1) {
    return res.status(409).json({ error: 'An account with this email address already exists. Please log in.' });
  }

  const usernameCheck = db.prepare('SELECT user_id FROM user_profiles WHERE username = ?').get(cleanUsername);
  if (usernameCheck && (!existing || usernameCheck.user_id !== existing.id)) {
    return res.status(409).json({ error: 'This username is already taken. Please choose another.' });
  }

  const salt = generateSalt();
  const hash = hashPassword(password, salt);
  const verificationCode = generateSixDigitCode();
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString(); // 15 minutes
  const now = new Date().toISOString();
  const userId = existing ? existing.id : crypto.randomUUID();

  if (existing) {
    db.prepare(`
      UPDATE users SET
        password_hash = ?,
        password_salt = ?,
        verification_token = ?,
        verification_expires_at = ?,
        email_verified = 0
      WHERE id = ?
    `).run(hash, salt, verificationCode, expiresAt, userId);
  } else {
    db.prepare(`
      INSERT INTO users (id, email, password_hash, password_salt, email_verified, verification_token, verification_expires_at, role, status, created_at)
      VALUES (?, ?, ?, ?, 0, ?, ?, 'user', 'active', ?)
    `).run(userId, cleanEmail, hash, salt, verificationCode, expiresAt, now);

    db.prepare(`
      INSERT INTO user_profiles (user_id, username, display_name, updated_at)
      VALUES (?, ?, ?, ?)
    `).run(userId, cleanUsername, displayName || cleanUsername, now);
  }

  console.log(`[Auth] Verification code for ${cleanEmail}: ${verificationCode}`);

  return res.status(201).json({
    message: 'Registration successful! Verification code sent to email.',
    email: cleanEmail,
    requiresVerification: true,
    // In production with custom SMTP, code is delivered via email; for dev/test verification convenience:
    verificationCodeDev: process.env.NODE_ENV !== 'production' ? verificationCode : undefined
  });
});

// 2. Verify Email Code
authRouter.post('/verify-email', (req, res) => {
  const { email, code } = req.body;
  if (!email || !code) {
    return res.status(400).json({ error: 'Email and 6-digit verification code are required.' });
  }

  const cleanEmail = email.trim().toLowerCase();
  const user = db.prepare(`
    SELECT u.*, p.username, p.display_name
    FROM users u
    LEFT JOIN user_profiles p ON p.user_id = u.id
    WHERE u.email = ?
  `).get(cleanEmail);

  if (!user) {
    return res.status(404).json({ error: 'User account not found.' });
  }

  if (user.verification_token !== code.trim()) {
    return res.status(400).json({ error: 'Invalid verification code. Please try again.' });
  }

  if (new Date(user.verification_expires_at) < new Date()) {
    return res.status(400).json({ error: 'Verification code has expired. Request a new one.' });
  }

  db.prepare(`
    UPDATE users SET
      email_verified = 1,
      verification_token = NULL,
      verification_expires_at = NULL,
      last_login_at = ?
    WHERE id = ?
  `).run(new Date().toISOString(), user.id);

  // Issue session
  const token = generateToken();
  const sessionExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(); // 30 days
  db.prepare(`
    INSERT INTO active_sessions (token, user_id, role, mfa_verified, expires_at)
    VALUES (?, ?, ?, 0, ?)
  `).run(token, user.id, user.role, sessionExpiresAt);

  return res.json({
    message: 'Email verified successfully!',
    token,
    user: {
      id: user.id,
      email: user.email,
      username: user.username,
      displayName: user.display_name,
      role: user.role,
      emailVerified: true
    }
  });
});

// 3. Resend Verification Code
authRouter.post('/resend-code', (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email address is required.' });

  const cleanEmail = email.trim().toLowerCase();
  const user = db.prepare('SELECT id, email_verified FROM users WHERE email = ?').get(cleanEmail);
  if (!user) {
    return res.status(404).json({ error: 'No account associated with this email.' });
  }
  if (user.email_verified === 1) {
    return res.status(400).json({ error: 'This email is already verified. Please sign in.' });
  }

  const verificationCode = generateSixDigitCode();
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
  db.prepare('UPDATE users SET verification_token = ?, verification_expires_at = ? WHERE id = ?')
    .run(verificationCode, expiresAt, user.id);

  console.log(`[Auth] Resent verification code for ${cleanEmail}: ${verificationCode}`);

  return res.json({
    message: 'Fresh 6-digit verification code sent.',
    verificationCodeDev: process.env.NODE_ENV !== 'production' ? verificationCode : undefined
  });
});

// 4. User Login
authRouter.post('/login', (req, res) => {
  const ip = req.ip || req.socket.remoteAddress;
  const rate = checkRateLimit(`login_${ip}`, 10, 60000);
  if (!rate.allowed) {
    return res.status(429).json({ error: `Too many login attempts. Retry in ${rate.retryAfterSeconds}s.` });
  }

  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required.' });
  }

  const cleanEmail = email.trim().toLowerCase();
  const user = db.prepare(`
    SELECT u.*, p.username, p.display_name, p.avatar_url, p.experience_level, p.xp_points
    FROM users u
    LEFT JOIN user_profiles p ON p.user_id = u.id
    WHERE u.email = ?
  `).get(cleanEmail);

  if (!user) {
    return res.status(401).json({ error: 'Invalid email or password.' });
  }

  if (user.status === 'suspended') {
    return res.status(403).json({ error: 'Your account has been suspended by administration.' });
  }

  if (!verifyPassword(password, user.password_salt, user.password_hash)) {
    return res.status(401).json({ error: 'Invalid email or password.' });
  }

  if (user.email_verified !== 1) {
    return res.status(403).json({
      error: 'Your email address has not been verified yet.',
      requiresEmailVerification: true,
      email: user.email
    });
  }

  const token = generateToken();
  const sessionExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const now = new Date().toISOString();

  db.prepare('UPDATE users SET last_login_at = ? WHERE id = ?').run(now, user.id);
  db.prepare(`
    INSERT INTO active_sessions (token, user_id, role, mfa_verified, expires_at)
    VALUES (?, ?, ?, 0, ?)
  `).run(token, user.id, user.role, sessionExpiresAt);

  return res.json({
    message: 'Signed in successfully.',
    token,
    user: {
      id: user.id,
      email: user.email,
      username: user.username,
      displayName: user.display_name,
      avatarUrl: user.avatar_url,
      experienceLevel: user.experience_level,
      xpPoints: user.xp_points,
      role: user.role,
      emailVerified: true
    }
  });
});

// 5. Password Reset Request
authRouter.post('/forgot-password', (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email address is required.' });

  const cleanEmail = email.trim().toLowerCase();
  const user = db.prepare('SELECT id FROM users WHERE email = ?').get(cleanEmail);
  if (!user) {
    return res.json({ message: 'If this email exists in our system, a password reset code has been dispatched.' });
  }

  const resetCode = generateSixDigitCode();
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
  db.prepare('UPDATE users SET reset_token = ?, reset_expires_at = ? WHERE id = ?')
    .run(resetCode, expiresAt, user.id);

  console.log(`[Auth] Password reset code for ${cleanEmail}: ${resetCode}`);

  return res.json({
    message: 'If this email exists in our system, a password reset code has been dispatched.',
    resetCodeDev: process.env.NODE_ENV !== 'production' ? resetCode : undefined
  });
});

// 6. Reset Password with Code
authRouter.post('/reset-password', (req, res) => {
  const { email, code, newPassword } = req.body;
  if (!email || !code || !newPassword) {
    return res.status(400).json({ error: 'Email, verification code, and new password are required.' });
  }

  if (newPassword.length < 8) {
    return res.status(400).json({ error: 'Password must be at least 8 characters long.' });
  }

  const cleanEmail = email.trim().toLowerCase();
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(cleanEmail);
  if (!user || user.reset_token !== code.trim()) {
    return res.status(400).json({ error: 'Invalid or expired password reset code.' });
  }

  if (new Date(user.reset_expires_at) < new Date()) {
    return res.status(400).json({ error: 'Reset code has expired. Please request a new one.' });
  }

  const newSalt = generateSalt();
  const newHash = hashPassword(newPassword, newSalt);

  db.prepare(`
    UPDATE users SET
      password_hash = ?,
      password_salt = ?,
      reset_token = NULL,
      reset_expires_at = NULL
    WHERE id = ?
  `).run(newHash, newSalt, user.id);

  // Invalidate any existing sessions for security
  db.prepare('UPDATE active_sessions SET is_revoked = 1 WHERE user_id = ?').run(user.id);

  return res.json({ message: 'Password has been updated securely. Please sign in with your new password.' });
});

// 7. Change Password (Authenticated)
authRouter.post('/change-password', authenticate, (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Current password and new password are required.' });
  }

  if (newPassword.length < 8) {
    return res.status(400).json({ error: 'New password must be at least 8 characters long.' });
  }

  const user = db.prepare('SELECT password_hash, password_salt FROM users WHERE id = ?').get(req.user.id);
  if (!verifyPassword(currentPassword, user.password_salt, user.password_hash)) {
    return res.status(400).json({ error: 'Incorrect current password.' });
  }

  const newSalt = generateSalt();
  const newHash = hashPassword(newPassword, newSalt);
  db.prepare('UPDATE users SET password_hash = ?, password_salt = ? WHERE id = ?')
    .run(newHash, newSalt, req.user.id);

  return res.json({ message: 'Password updated successfully.' });
});

// 8. Get Current Profile
authRouter.get('/me', authenticate, (req, res) => {
  const profile = db.prepare(`
    SELECT u.id, u.email, u.role, u.status, u.created_at, u.last_login_at,
           p.username, p.display_name, p.avatar_url, p.bio, p.experience_level, p.units, p.xp_points, p.level
    FROM users u
    LEFT JOIN user_profiles p ON p.user_id = u.id
    WHERE u.id = ?
  `).get(req.user.id);

  if (!profile) return res.status(404).json({ error: 'Profile not found.' });
  return res.json({ user: profile });
});

// 9. Update Current Profile
authRouter.put('/me', authenticate, (req, res) => {
  const { displayName, bio, experienceLevel, units } = req.body;
  const now = new Date().toISOString();

  db.prepare(`
    UPDATE user_profiles SET
      display_name = COALESCE(?, display_name),
      bio = COALESCE(?, bio),
      experience_level = COALESCE(?, experience_level),
      units = COALESCE(?, units),
      updated_at = ?
    WHERE user_id = ?
  `).run(displayName, bio, experienceLevel, units, now, req.user.id);

  return res.json({ message: 'Profile updated successfully.' });
});

// 10. Delete Account
authRouter.delete('/delete-account', authenticate, (req, res) => {
  const userId = req.user.id;
  // Cascades to user_profiles, active_sessions, workouts
  db.prepare('DELETE FROM users WHERE id = ?').run(userId);
  db.prepare('DELETE FROM active_sessions WHERE user_id = ?').run(userId);
  return res.json({ message: 'Your account and private data have been permanently purged.' });
});

// 11. Logout
authRouter.post('/logout', authenticate, (req, res) => {
  db.prepare('UPDATE active_sessions SET is_revoked = 1 WHERE token = ?').run(req.sessionToken);
  return res.json({ message: 'Signed out successfully.' });
});

