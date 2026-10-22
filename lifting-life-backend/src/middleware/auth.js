import { db } from '../db.js';
import crypto from 'node:crypto';

export function authenticate(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication token required.' });
  }

  const token = authHeader.substring(7).trim();
  const session = db.prepare(`
    SELECT s.*, u.status, u.email
    FROM active_sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.token = ? AND s.is_revoked = 0
  `).get(token);

  if (!session) {
    return res.status(401).json({ error: 'Invalid or revoked session token.' });
  }

  if (new Date(session.expires_at) < new Date()) {
    db.prepare('UPDATE active_sessions SET is_revoked = 1 WHERE token = ?').run(token);
    return res.status(401).json({ error: 'Session has expired. Please sign in again.' });
  }

  if (session.status === 'suspended') {
    return res.status(403).json({ error: 'This account has been suspended by administration.' });
  }

  req.sessionToken = token;
  req.user = {
    id: session.user_id,
    email: session.email,
    role: session.role,
    mfaVerified: session.mfa_verified === 1
  };

  next();
}

export function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: `Access denied. Requires one of roles: [${allowedRoles.join(', ')}]. Your role: ${req.user.role}`
      });
    }
    next();
  };
}

export function requireAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ error: 'Authentication required.' });
  }
  const adminRoles = ['super_admin', 'admin', 'content_manager', 'support_staff'];
  if (!adminRoles.includes(req.user.role)) {
    return res.status(403).json({ error: 'Access denied. Administrative privileges required.' });
  }

  // Verify MFA has been satisfied for administrative actions
  if (!req.user.mfaVerified) {
    return res.status(403).json({
      error: 'Multifactor authentication (MFA) verification required to access administrative features.',
      requiresMfa: true
    });
  }

  next();
}

export function recordAuditLog(req, { action, targetType, targetId, details }) {
  try {
    const logId = crypto.randomUUID();
    const adminId = req.user ? req.user.id : 'anonymous';
    const adminEmail = req.user ? req.user.email : 'system';
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || '127.0.0.1';
    const now = new Date().toISOString();

    db.prepare(`
      INSERT INTO admin_audit_logs (id, admin_id, admin_email, action, target_type, target_id, details, ip_address, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      logId,
      adminId,
      adminEmail,
      action,
      targetType,
      targetId ? String(targetId) : null,
      typeof details === 'object' ? JSON.stringify(details) : String(details || ''),
      ip,
      now
    );
  } catch (err) {
    console.error('[Audit Log] Failed to record:', err);
  }
}

