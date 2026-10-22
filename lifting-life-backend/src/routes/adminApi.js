import express from 'express';
import crypto from 'node:crypto';
import { db } from '../db.js';
import { authenticate, requireAdmin, requireRole, recordAuditLog } from '../middleware/auth.js';
import { generateToken, generateSixDigitCode } from '../security.js';

export const adminApiRouter = express.Router();

// Enforce authentication & admin privileges with verified MFA on all routes
adminApiRouter.use(authenticate);
adminApiRouter.use(requireAdmin);

// ============================================================================
// 1. DASHBOARD OVERVIEW & ANALYTICS
// ============================================================================
adminApiRouter.get('/stats', (req, res) => {
  const range = (req.query.range || 'all').toLowerCase();
  let timeFilterSql = '';
  const now = new Date();

  if (range === '24h') {
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
    timeFilterSql = `AND created_at >= '${yesterday}'`;
  } else if (range === '7d') {
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
    timeFilterSql = `AND created_at >= '${weekAgo}'`;
  } else if (range === '30d') {
    const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
    timeFilterSql = `AND created_at >= '${monthAgo}'`;
  }

  const totalUsers = db.prepare('SELECT count(*) as count FROM users').get().count;
  const newRegistrations = db.prepare(`SELECT count(*) as count FROM users WHERE 1=1 ${timeFilterSql}`).get().count;
  const activeUsers = db.prepare(`SELECT count(DISTINCT user_id) as count FROM active_sessions WHERE is_revoked = 0`).get().count;
  const totalWorkouts = db.prepare('SELECT count(*) as count FROM workouts').get().count;
  const totalExercises = db.prepare('SELECT count(*) as count FROM exercises WHERE is_published = 1').get().count;
  const totalTemplates = db.prepare('SELECT count(*) as count FROM workout_templates').get().count;
  const totalPrograms = db.prepare('SELECT count(*) as count FROM training_programs').get().count;

  // Recent 6 registrations (sanitized — no passwords or secrets)
  const recentUsers = db.prepare(`
    SELECT u.id, u.email, u.role, u.status, u.created_at, u.last_login_at,
           p.username, p.display_name
    FROM users u
    LEFT JOIN user_profiles p ON p.user_id = u.id
    ORDER BY u.created_at DESC
    LIMIT 6
  `).all();

  // Exercise distribution by muscle category
  const categories = db.prepare(`
    SELECT category, count(*) as count
    FROM exercises
    GROUP BY category
    ORDER BY count DESC
    LIMIT 8
  `).all();

  return res.json({
    kpis: {
      totalUsers,
      newRegistrations,
      activeUsers: Math.max(activeUsers, 1),
      totalWorkouts,
      totalExercises,
      totalTemplates,
      totalPrograms,
      systemStatus: 'Operational',
      errorCount: 0
    },
    recentUsers,
    categories,
    systemHealth: {
      uptimeSeconds: Math.floor(process.uptime()),
      memoryUsageMb: Math.round(process.memoryUsage().rss / (1024 * 1024)),
      databaseEngine: 'SQLite Native Sync (Node 22)',
      environment: process.env.NODE_ENV || 'production'
    }
  });
});

// ============================================================================
// 2. USER MANAGEMENT
// ============================================================================
adminApiRouter.get('/users', (req, res) => {
  const search = (req.query.search || '').trim().toLowerCase();
  const status = (req.query.status || 'all').trim().toLowerCase();
  const role = (req.query.role || 'all').trim().toLowerCase();
  const page = Math.max(parseInt(req.query.page) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit) || 20, 1), 100);
  const offset = (page - 1) * limit;

  let whereClauses = [];
  let params = [];

  if (search) {
    whereClauses.push('(LOWER(u.email) LIKE ? OR LOWER(p.username) LIKE ? OR LOWER(p.display_name) LIKE ?)');
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (status !== 'all') {
    whereClauses.push('u.status = ?');
    params.push(status);
  }
  if (role !== 'all') {
    whereClauses.push('u.role = ?');
    params.push(role);
  }

  const whereSql = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

  const totalCount = db.prepare(`
    SELECT count(*) as count
    FROM users u
    LEFT JOIN user_profiles p ON p.user_id = u.id
    ${whereSql}
  `).get(...params).count;

  const users = db.prepare(`
    SELECT u.id, u.email, u.email_verified, u.role, u.status, u.created_at, u.last_login_at,
           p.username, p.display_name, p.experience_level, p.xp_points,
           (SELECT count(*) FROM workouts w WHERE w.user_id = u.id) as workout_count
    FROM users u
    LEFT JOIN user_profiles p ON p.user_id = u.id
    ${whereSql}
    ORDER BY u.created_at DESC
    LIMIT ? OFFSET ?
  `).all(...params, limit, offset);

  return res.json({
    users,
    pagination: {
      page,
      limit,
      totalCount,
      totalPages: Math.ceil(totalCount / limit)
    }
  });
});

adminApiRouter.get('/users/:id', (req, res) => {
  const user = db.prepare(`
    SELECT u.id, u.email, u.email_verified, u.role, u.status, u.created_at, u.last_login_at,
           p.username, p.display_name, p.bio, p.experience_level, p.units, p.xp_points, p.level,
           (SELECT count(*) FROM workouts w WHERE w.user_id = u.id) as workout_count
    FROM users u
    LEFT JOIN user_profiles p ON p.user_id = u.id
    WHERE u.id = ?
  `).get(req.params.id);

  if (!user) return res.status(404).json({ error: 'User account not found.' });
  return res.json({ user });
});

// Suspend or Reactivate Account
adminApiRouter.patch('/users/:id/status', (req, res) => {
  const { status, reason } = req.body;
  if (!['active', 'suspended'].includes(status)) {
    return res.status(400).json({ error: 'Status must be active or suspended.' });
  }

  const user = db.prepare('SELECT id, email, role FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ error: 'User account not found.' });

  if (user.role === 'super_admin') {
    return res.status(403).json({ error: 'Super Administrator accounts cannot be suspended.' });
  }

  db.prepare('UPDATE users SET status = ? WHERE id = ?').run(status, user.id);

  // If suspended, revoke all active sessions immediately
  if (status === 'suspended') {
    db.prepare('UPDATE active_sessions SET is_revoked = 1 WHERE user_id = ?').run(user.id);
  }

  recordAuditLog(req, {
    action: status === 'suspended' ? 'user_suspend' : 'user_reactivate',
    targetType: 'user',
    targetId: user.id,
    details: { email: user.email, newStatus: status, reason: reason || 'Administrative decision' }
  });

  return res.json({
    message: `Account for ${user.email} is now ${status}.`,
    user: { id: user.id, status }
  });
});

// Change Role (Super Admin Only)
adminApiRouter.patch('/users/:id/role', requireRole('super_admin'), (req, res) => {
  const { role } = req.body;
  const allowed = ['user', 'support_staff', 'content_manager', 'admin', 'super_admin'];
  if (!allowed.includes(role)) {
    return res.status(400).json({ error: `Role must be one of: ${allowed.join(', ')}` });
  }

  const user = db.prepare('SELECT id, email, role FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ error: 'User account not found.' });

  db.prepare('UPDATE users SET role = ? WHERE id = ?').run(role, user.id);
  // Update role on active sessions
  db.prepare('UPDATE active_sessions SET role = ? WHERE user_id = ?').run(role, user.id);

  recordAuditLog(req, {
    action: 'user_role_change',
    targetType: 'user',
    targetId: user.id,
    details: { email: user.email, oldRole: user.role, newRole: role }
  });

  return res.json({
    message: `Role for ${user.email} changed to ${role}.`,
    user: { id: user.id, role }
  });
});

// Account Recovery Workflow
adminApiRouter.post('/users/:id/recovery', (req, res) => {
  const user = db.prepare('SELECT id, email FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ error: 'User account not found.' });

  const recoveryCode = generateSixDigitCode();
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString(); // 1 hour

  db.prepare('UPDATE users SET reset_token = ?, reset_expires_at = ? WHERE id = ?')
    .run(recoveryCode, expiresAt, user.id);

  recordAuditLog(req, {
    action: 'user_recovery_initiated',
    targetType: 'user',
    targetId: user.id,
    details: { email: user.email }
  });

  return res.json({
    message: 'Authorized recovery credentials generated.',
    email: user.email,
    recoveryCode,
    expiresAt
  });
});

// Permanent Account Deletion upon verified request
adminApiRouter.delete('/users/:id', requireRole('super_admin', 'admin'), (req, res) => {
  const user = db.prepare('SELECT id, email, role FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ error: 'User account not found.' });

  if (user.role === 'super_admin') {
    return res.status(403).json({ error: 'Super Administrator accounts cannot be deleted directly.' });
  }

  db.prepare('DELETE FROM users WHERE id = ?').run(user.id);
  db.prepare('DELETE FROM active_sessions WHERE user_id = ?').run(user.id);

  recordAuditLog(req, {
    action: 'user_account_deleted',
    targetType: 'user',
    targetId: user.id,
    details: { email: user.email }
  });

  return res.json({ message: `Account for ${user.email} and all private cloud data permanently purged.` });
});

// ============================================================================
// 3. EXERCISE LIBRARY MANAGEMENT
// ============================================================================
adminApiRouter.get('/exercises', (req, res) => {
  const search = (req.query.search || '').trim().toLowerCase();
  const category = (req.query.category || 'all').trim();
  const equipment = (req.query.equipment || 'all').trim();
  const published = req.query.published;
  const page = Math.max(parseInt(req.query.page) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit) || 20, 1), 100);
  const offset = (page - 1) * limit;

  let whereClauses = [];
  let params = [];

  if (search) {
    whereClauses.push('(LOWER(name) LIKE ? OR LOWER(primary_muscle) LIKE ?)');
    params.push(`%${search}%`, `%${search}%`);
  }
  if (category !== 'all') {
    whereClauses.push('category = ?');
    params.push(category);
  }
  if (equipment !== 'all') {
    whereClauses.push('equipment = ?');
    params.push(equipment);
  }
  if (published !== undefined && published !== 'all') {
    whereClauses.push('is_published = ?');
    params.push(published === 'true' || published === '1' ? 1 : 0);
  }

  const whereSql = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

  const totalCount = db.prepare(`SELECT count(*) as count FROM exercises ${whereSql}`).get(...params).count;
  const exercises = db.prepare(`
    SELECT * FROM exercises
    ${whereSql}
    ORDER BY name ASC
    LIMIT ? OFFSET ?
  `).all(...params, limit, offset);

  const parsed = exercises.map(e => ({
    ...e,
    secondaryMuscles: JSON.parse(e.secondary_muscles || '[]'),
    instructions: JSON.parse(e.instructions || '[]'),
    isPublished: e.is_published === 1,
    isFeatured: e.is_featured === 1
  }));

  return res.json({
    exercises: parsed,
    pagination: {
      page,
      limit,
      totalCount,
      totalPages: Math.ceil(totalCount / limit)
    }
  });
});

adminApiRouter.get('/exercises/:id', (req, res) => {
  const ex = db.prepare('SELECT * FROM exercises WHERE id = ?').get(req.params.id);
  if (!ex) return res.status(404).json({ error: 'Exercise not found.' });

  return res.json({
    exercise: {
      ...ex,
      secondaryMuscles: JSON.parse(ex.secondary_muscles || '[]'),
      instructions: JSON.parse(ex.instructions || '[]'),
      isPublished: ex.is_published === 1,
      isFeatured: ex.is_featured === 1
    }
  });
});

// Add New Exercise
adminApiRouter.post('/exercises', (req, res) => {
  const {
    name, category, equipment, primaryMuscle, secondaryMuscles,
    difficulty, suggestedSets, suggestedReps, restSeconds,
    instructions, description, mediaUrl, mediaType, isFeatured
  } = req.body;

  if (!name || !category || !equipment || !primaryMuscle) {
    return res.status(400).json({ error: 'Name, category, equipment, and primary muscle are required.' });
  }

  // Duplicate check
  const duplicate = db.prepare('SELECT id, name FROM exercises WHERE LOWER(name) = ?').get(name.trim().toLowerCase());
  if (duplicate) {
    return res.status(409).json({ error: `An exercise with the name "${duplicate.name}" already exists.` });
  }

  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  db.prepare(`
    INSERT INTO exercises (
      id, name, category, equipment, primary_muscle, secondary_muscles,
      difficulty, suggested_sets, suggested_reps, rest_seconds, instructions,
      description, media_url, media_type, is_published, is_featured, source,
      created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, 'admin', ?, ?)
  `).run(
    id,
    name.trim(),
    category.trim(),
    equipment.trim(),
    primaryMuscle.trim(),
    JSON.stringify(secondaryMuscles || []),
    difficulty || 'Intermediate',
    parseInt(suggestedSets) || 3,
    suggestedReps || '8-12',
    parseInt(restSeconds) || 90,
    JSON.stringify(instructions || []),
    description || '',
    mediaUrl || null,
    mediaType || 'diagram',
    isFeatured ? 1 : 0,
    now,
    now
  );

  recordAuditLog(req, {
    action: 'exercise_created',
    targetType: 'exercise',
    targetId: id,
    details: { name: name.trim(), category, equipment }
  });

  return res.status(201).json({
    message: 'Exercise created successfully!',
    id
  });
});

// Update Existing Exercise
adminApiRouter.put('/exercises/:id', (req, res) => {
  const existing = db.prepare('SELECT * FROM exercises WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Exercise not found.' });

  const {
    name, category, equipment, primaryMuscle, secondaryMuscles,
    difficulty, suggestedSets, suggestedReps, restSeconds,
    instructions, description, mediaUrl, mediaType, isFeatured, isPublished
  } = req.body;

  const now = new Date().toISOString();

  db.prepare(`
    UPDATE exercises SET
      name = COALESCE(?, name),
      category = COALESCE(?, category),
      equipment = COALESCE(?, equipment),
      primary_muscle = COALESCE(?, primary_muscle),
      secondary_muscles = COALESCE(?, secondary_muscles),
      difficulty = COALESCE(?, difficulty),
      suggested_sets = COALESCE(?, suggested_sets),
      suggested_reps = COALESCE(?, suggested_reps),
      rest_seconds = COALESCE(?, rest_seconds),
      instructions = COALESCE(?, instructions),
      description = COALESCE(?, description),
      media_url = ?,
      media_type = COALESCE(?, media_type),
      is_featured = COALESCE(?, is_featured),
      is_published = COALESCE(?, is_published),
      updated_at = ?
    WHERE id = ?
  `).run(
    name ? name.trim() : null,
    category ? category.trim() : null,
    equipment ? equipment.trim() : null,
    primaryMuscle ? primaryMuscle.trim() : null,
    secondaryMuscles ? JSON.stringify(secondaryMuscles) : null,
    difficulty || null,
    suggestedSets ? parseInt(suggestedSets) : null,
    suggestedReps || null,
    restSeconds ? parseInt(restSeconds) : null,
    instructions ? JSON.stringify(instructions) : null,
    description !== undefined ? description : null,
    mediaUrl !== undefined ? mediaUrl : existing.media_url,
    mediaType || null,
    isFeatured !== undefined ? (isFeatured ? 1 : 0) : null,
    isPublished !== undefined ? (isPublished ? 1 : 0) : null,
    now,
    req.params.id
  );

  recordAuditLog(req, {
    action: 'exercise_updated',
    targetType: 'exercise',
    targetId: req.params.id,
    details: { name: name || existing.name }
  });

  return res.json({ message: 'Exercise updated successfully.' });
});

// Toggle Publish State
adminApiRouter.patch('/exercises/:id/publish', (req, res) => {
  const ex = db.prepare('SELECT id, name, is_published FROM exercises WHERE id = ?').get(req.params.id);
  if (!ex) return res.status(404).json({ error: 'Exercise not found.' });

  const nextState = ex.is_published === 1 ? 0 : 1;
  const now = new Date().toISOString();
  db.prepare('UPDATE exercises SET is_published = ?, updated_at = ? WHERE id = ?').run(nextState, now, ex.id);

  recordAuditLog(req, {
    action: nextState === 1 ? 'exercise_published' : 'exercise_unpublished',
    targetType: 'exercise',
    targetId: ex.id,
    details: { name: ex.name, published: nextState === 1 }
  });

  return res.json({
    message: `Exercise is now ${nextState === 1 ? 'published' : 'unpublished'}.`,
    isPublished: nextState === 1
  });
});

// Delete or Archive Exercise
adminApiRouter.delete('/exercises/:id', requireRole('super_admin', 'admin'), (req, res) => {
  const ex = db.prepare('SELECT id, name FROM exercises WHERE id = ?').get(req.params.id);
  if (!ex) return res.status(404).json({ error: 'Exercise not found.' });

  db.prepare('DELETE FROM exercises WHERE id = ?').run(ex.id);

  recordAuditLog(req, {
    action: 'exercise_deleted',
    targetType: 'exercise',
    targetId: ex.id,
    details: { name: ex.name }
  });

  return res.json({ message: `Exercise "${ex.name}" removed from library.` });
});

// Duplicate Detector
adminApiRouter.get('/exercises-duplicates', (req, res) => {
  const duplicates = db.prepare(`
    SELECT LOWER(name) as clean_name, count(*) as count, group_concat(id) as ids
    FROM exercises
    GROUP BY clean_name
    HAVING count > 1
  `).all();

  return res.json({ duplicates });
});

// ============================================================================
// 4. WORKOUT & TRAINING CONTENT MANAGEMENT
// ============================================================================
adminApiRouter.get('/programs', (req, res) => {
  const programs = db.prepare('SELECT * FROM training_programs ORDER BY created_at DESC').all();
  return res.json({
    programs: programs.map(p => ({
      ...p,
      isPublic: p.is_public === 1,
      isFeatured: p.is_featured === 1
    }))
  });
});

adminApiRouter.post('/programs', (req, res) => {
  const { title, description, level, durationWeeks, isPublic, isFeatured } = req.body;
  if (!title) return res.status(400).json({ error: 'Title is required.' });

  const id = crypto.randomUUID();
  const now = new Date().toISOString();
  db.prepare(`
    INSERT INTO training_programs (id, title, description, level, duration_weeks, is_public, is_featured, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id, title.trim(), description || '', level || 'Intermediate',
    parseInt(durationWeeks) || 4, isPublic ? 1 : 0, isFeatured ? 1 : 0, now
  );

  recordAuditLog(req, {
    action: 'program_created', targetType: 'training_program', targetId: id, details: { title }
  });

  return res.status(201).json({ message: 'Training program published.', id });
});

adminApiRouter.put('/programs/:id', (req, res) => {
  const { title, description, level, durationWeeks, isPublic, isFeatured } = req.body;
  db.prepare(`
    UPDATE training_programs SET
      title = COALESCE(?, title),
      description = COALESCE(?, description),
      level = COALESCE(?, level),
      duration_weeks = COALESCE(?, duration_weeks),
      is_public = COALESCE(?, is_public),
      is_featured = COALESCE(?, is_featured)
    WHERE id = ?
  `).run(
    title, description, level, durationWeeks ? parseInt(durationWeeks) : null,
    isPublic !== undefined ? (isPublic ? 1 : 0) : null,
    isFeatured !== undefined ? (isFeatured ? 1 : 0) : null,
    req.params.id
  );

  recordAuditLog(req, {
    action: 'program_updated', targetType: 'training_program', targetId: req.params.id, details: { title }
  });

  return res.json({ message: 'Program updated successfully.' });
});

adminApiRouter.delete('/programs/:id', requireRole('super_admin', 'admin'), (req, res) => {
  db.prepare('DELETE FROM training_programs WHERE id = ?').run(req.params.id);
  recordAuditLog(req, { action: 'program_deleted', targetType: 'training_program', targetId: req.params.id, details: '' });
  return res.json({ message: 'Program deleted.' });
});

// Manage Public Templates
adminApiRouter.get('/templates', (req, res) => {
  const templates = db.prepare('SELECT * FROM workout_templates WHERE is_public = 1 ORDER BY created_at DESC').all();
  return res.json({
    templates: templates.map(t => ({
      ...t,
      exercises: JSON.parse(t.exercises_json || '[]'),
      isPublic: t.is_public === 1,
      isFeatured: t.is_featured === 1
    }))
  });
});

// ============================================================================
// 5. APPLICATION SETTINGS & FEATURE FLAGS
// ============================================================================
adminApiRouter.get('/settings', (req, res) => {
  const rows = db.prepare('SELECT * FROM system_settings').all();
  const settings = {};
  for (const r of rows) {
    try {
      settings[r.key] = JSON.parse(r.value);
    } catch (_) {
      settings[r.key] = r.value;
    }
  }
  return res.json({ settings });
});

adminApiRouter.put('/settings', requireRole('super_admin', 'admin'), (req, res) => {
  const { key, value } = req.body;
  if (!key || value === undefined) {
    return res.status(400).json({ error: 'Setting key and value are required.' });
  }

  // Prevent modifying internal secrets from ordinary settings endpoint
  if (['jwt_secret', 'database_key', 'encryption_seed'].includes(key.toLowerCase())) {
    return res.status(403).json({ error: 'Security infrastructure secrets cannot be modified via API.' });
  }

  const strValue = typeof value === 'object' ? JSON.stringify(value) : String(value);
  const now = new Date().toISOString();

  db.prepare(`
    INSERT INTO system_settings (key, value, updated_by, updated_at)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(key) DO UPDATE SET
      value = excluded.value,
      updated_by = excluded.updated_by,
      updated_at = excluded.updated_at
  `).run(key, strValue, req.user.email, now);

  recordAuditLog(req, {
    action: 'settings_updated',
    targetType: 'system_settings',
    targetId: key,
    details: { key, updatedBy: req.user.email }
  });

  return res.json({ message: `Setting "${key}" updated successfully.` });
});

// ============================================================================
// 6. ADMIN INVITATIONS & TEAM
// ============================================================================
adminApiRouter.get('/invitations', (req, res) => {
  const invitations = db.prepare(`
    SELECT i.*, u.email as invited_by_email
    FROM admin_invitations i
    LEFT JOIN users u ON u.id = i.invited_by
    WHERE i.accepted_at IS NULL
    ORDER BY i.created_at DESC
  `).all();

  return res.json({ invitations });
});

adminApiRouter.post('/invitations', requireRole('super_admin', 'admin'), (req, res) => {
  const { email, role } = req.body;
  const allowed = ['support_staff', 'content_manager', 'admin'];
  if (req.user.role === 'super_admin') allowed.push('super_admin');

  if (!email || !allowed.includes(role)) {
    return res.status(400).json({ error: `Valid email and role in [${allowed.join(', ')}] are required.` });
  }

  const cleanEmail = email.trim().toLowerCase();
  const existingUser = db.prepare('SELECT id, role FROM users WHERE email = ?').get(cleanEmail);
  if (existingUser && ['super_admin', 'admin'].includes(existingUser.role)) {
    return res.status(409).json({ error: 'An administrator with this email already exists.' });
  }

  const token = generateToken();
  const id = crypto.randomUUID();
  const now = new Date().toISOString();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(); // 7 days

  db.prepare(`
    INSERT INTO admin_invitations (id, email, role, token, invited_by, created_at, expires_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(email) DO UPDATE SET
      role = excluded.role,
      token = excluded.token,
      invited_by = excluded.invited_by,
      created_at = excluded.created_at,
      expires_at = excluded.expires_at,
      accepted_at = NULL
  `).run(id, cleanEmail, role, token, req.user.id, now, expiresAt);

  recordAuditLog(req, {
    action: 'admin_invitation_created',
    targetType: 'admin_invitation',
    targetId: id,
    details: { email: cleanEmail, role }
  });

  return res.status(201).json({
    message: `Invitation generated for ${cleanEmail}.`,
    invitation: {
      id,
      email: cleanEmail,
      role,
      token,
      inviteLink: `http://localhost:3000/accept-invite?token=${token}`
    }
  });
});

adminApiRouter.delete('/invitations/:id', requireRole('super_admin', 'admin'), (req, res) => {
  db.prepare('DELETE FROM admin_invitations WHERE id = ?').run(req.params.id);
  recordAuditLog(req, {
    action: 'admin_invitation_revoked',
    targetType: 'admin_invitation',
    targetId: req.params.id,
    details: ''
  });
  return res.json({ message: 'Invitation revoked.' });
});

// ============================================================================
// 7. AUDIT LOGS
// ============================================================================
adminApiRouter.get('/audit-logs', (req, res) => {
  const page = Math.max(parseInt(req.query.page) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit) || 25, 1), 100);
  const action = (req.query.action || '').trim();
  const offset = (page - 1) * limit;

  let whereSql = '';
  let params = [];
  if (action) {
    whereSql = 'WHERE action LIKE ?';
    params.push(`%${action}%`);
  }

  const totalCount = db.prepare(`SELECT count(*) as count FROM admin_audit_logs ${whereSql}`).get(...params).count;
  const logs = db.prepare(`
    SELECT * FROM admin_audit_logs
    ${whereSql}
    ORDER BY created_at DESC
    LIMIT ? OFFSET ?
  `).all(...params, limit, offset);

  return res.json({
    logs,
    pagination: {
      page,
      limit,
      totalCount,
      totalPages: Math.ceil(totalCount / limit)
    }
  });
});

