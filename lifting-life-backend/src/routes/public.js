import express from 'express';
import { db } from '../db.js';

export const publicRouter = express.Router();

// Public exercises endpoint (Used by Lifting Life application & website)
publicRouter.get('/exercises', (req, res) => {
  const search = (req.query.search || '').trim().toLowerCase();
  const category = (req.query.category || 'all').trim();
  const equipment = (req.query.equipment || 'all').trim();
  const page = Math.max(parseInt(req.query.page) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit) || 50, 1), 200);
  const offset = (page - 1) * limit;

  let whereClauses = ['is_published = 1'];
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

  const whereSql = `WHERE ${whereClauses.join(' AND ')}`;
  const totalCount = db.prepare(`SELECT count(*) as count FROM exercises ${whereSql}`).get(...params).count;
  const exercises = db.prepare(`
    SELECT id, name, category, equipment, primary_muscle, secondary_muscles,
           difficulty, suggested_sets, suggested_reps, rest_seconds, instructions,
           description, media_url, media_type, is_featured
    FROM exercises
    ${whereSql}
    ORDER BY is_featured DESC, name ASC
    LIMIT ? OFFSET ?
  `).all(...params, limit, offset);

  return res.json({
    exercises: exercises.map(e => ({
      ...e,
      secondaryMuscles: JSON.parse(e.secondary_muscles || '[]'),
      instructions: JSON.parse(e.instructions || '[]'),
      isFeatured: e.is_featured === 1
    })),
    pagination: {
      page,
      limit,
      totalCount,
      totalPages: Math.ceil(totalCount / limit)
    }
  });
});

// Public platform settings & announcements
publicRouter.get('/settings', (req, res) => {
  const rows = db.prepare('SELECT * FROM system_settings').all();
  const settings = {};
  for (const r of rows) {
    try {
      settings[r.key] = JSON.parse(r.value);
    } catch (_) {
      settings[r.key] = r.value;
    }
  }

  return res.json({
    status: 'online',
    announcement: settings.announcement || null,
    featureFlags: settings.feature_flags || {},
    maintenanceMode: settings.maintenance_mode?.enabled || false
  });
});

// Public training programs
publicRouter.get('/programs', (req, res) => {
  const programs = db.prepare(`
    SELECT * FROM training_programs
    WHERE is_public = 1
    ORDER BY is_featured DESC, title ASC
  `).all();

  return res.json({
    programs: programs.map(p => ({
      ...p,
      isFeatured: p.is_featured === 1
    }))
  });
});

