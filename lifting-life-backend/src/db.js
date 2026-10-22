import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const dbPath = path.resolve(__dirname, '../data/lifting_life.db');
const dbDir = path.dirname(dbPath);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

export const db = new DatabaseSync(dbPath);

export function initializeDatabase() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT,
      password_salt TEXT,
      email_verified INTEGER NOT NULL DEFAULT 0,
      verification_token TEXT,
      verification_expires_at TEXT,
      reset_token TEXT,
      reset_expires_at TEXT,
      role TEXT NOT NULL DEFAULT 'user',
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      last_login_at TEXT
    );

    CREATE TABLE IF NOT EXISTS user_profiles (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      username TEXT UNIQUE NOT NULL,
      display_name TEXT NOT NULL,
      avatar_url TEXT,
      bio TEXT DEFAULT '',
      experience_level TEXT DEFAULT 'Intermediate',
      units TEXT DEFAULT 'metric',
      xp_points INTEGER DEFAULT 0,
      level INTEGER DEFAULT 1,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS admin_mfa (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      totp_secret TEXT NOT NULL,
      is_enabled INTEGER NOT NULL DEFAULT 0,
      backup_codes TEXT,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS admin_invitations (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      role TEXT NOT NULL,
      token TEXT UNIQUE NOT NULL,
      invited_by TEXT,
      created_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      accepted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS admin_audit_logs (
      id TEXT PRIMARY KEY,
      admin_id TEXT,
      admin_email TEXT,
      action TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_id TEXT,
      details TEXT,
      ip_address TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS exercises (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      category TEXT NOT NULL,
      equipment TEXT NOT NULL,
      primary_muscle TEXT NOT NULL,
      secondary_muscles TEXT DEFAULT '[]',
      difficulty TEXT DEFAULT 'Intermediate',
      suggested_sets INTEGER DEFAULT 3,
      suggested_reps TEXT DEFAULT '8-12',
      rest_seconds INTEGER DEFAULT 90,
      instructions TEXT DEFAULT '[]',
      description TEXT DEFAULT '',
      media_url TEXT,
      media_type TEXT,
      is_published INTEGER NOT NULL DEFAULT 1,
      is_featured INTEGER NOT NULL DEFAULT 0,
      source TEXT DEFAULT 'system',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS workout_templates (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      name TEXT NOT NULL,
      category TEXT DEFAULT 'Custom',
      is_public INTEGER NOT NULL DEFAULT 0,
      is_featured INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      exercises_json TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS training_programs (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      level TEXT DEFAULT 'Intermediate',
      duration_weeks INTEGER DEFAULT 4,
      is_public INTEGER NOT NULL DEFAULT 1,
      is_featured INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS workouts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      date TEXT NOT NULL,
      duration_seconds INTEGER DEFAULT 0,
      exercises_json TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS system_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_by TEXT,
      updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS active_sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role TEXT NOT NULL,
      mfa_verified INTEGER NOT NULL DEFAULT 0,
      expires_at TEXT NOT NULL,
      is_revoked INTEGER NOT NULL DEFAULT 0
    );

    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
    CREATE INDEX IF NOT EXISTS idx_exercises_category ON exercises(category);
    CREATE INDEX IF NOT EXISTS idx_exercises_equipment ON exercises(equipment);
    CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON admin_audit_logs(created_at);
  `);

  seedInitialData();
}

function seedInitialData() {
  // 1. Settings
  const settingsCount = db.prepare('SELECT count(*) as count FROM system_settings').get().count;
  if (settingsCount === 0) {
    const insertSetting = db.prepare('INSERT INTO system_settings (key, value, updated_by, updated_at) VALUES (?, ?, ?, ?)');
    const now = new Date().toISOString();
    insertSetting.run('announcement', JSON.stringify({
      title: 'Welcome to Lifting Life Production',
      message: 'Platform updated with universal exercise catalogue and biometric analysis.',
      isActive: true,
      type: 'info'
    }), 'system', now);

    insertSetting.run('maintenance_mode', JSON.stringify({
      enabled: false,
      message: 'System is currently undergoing scheduled performance tuning.'
    }), 'system', now);

    insertSetting.run('feature_flags', JSON.stringify({
      enableLeaderboard: true,
      enableCommunityFeed: true,
      enableBeta3DViewer: true,
      enablePlateCalculator: true,
      requireMFAForAdmins: true
    }), 'system', now);
  }

  // 2. Default Public Training Programs
  const programCount = db.prepare('SELECT count(*) as count FROM training_programs').get().count;
  if (programCount === 0) {
    const insertProgram = db.prepare(`
      INSERT INTO training_programs (id, title, description, level, duration_weeks, is_public, is_featured, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);
    const now = new Date().toISOString();
    insertProgram.run('prog_ppl_hypertrophy', 'Push Pull Legs — Hypertrophy Mastery', '6-day classic hypertrophy protocol engineered for optimal muscle protein synthesis.', 'Intermediate', 8, 1, 1, now);
    insertProgram.run('prog_powerlifting_base', '5/3/1 Strength Periodization Base', 'Periodized strength cycle focusing on Barbell Squat, Bench Press, and Deadlift 1RM progression.', 'Advanced', 12, 1, 1, now);
    insertProgram.run('prog_foundation_start', 'Athletic Movement & Strength Foundation', '3-day full body training routine for building lean muscle mass and solid biomechanical habits.', 'Beginner', 6, 1, 0, now);
  }

  // 3. Default Public Workout Templates
  const templateCount = db.prepare('SELECT count(*) as count FROM workout_templates').get().count;
  if (templateCount === 0) {
    const insertTemplate = db.prepare(`
      INSERT INTO workout_templates (id, user_id, name, category, is_public, is_featured, notes, exercises_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    const now = new Date().toISOString();
    insertTemplate.run(
      'tpl_push_a', 'system', 'PPL — Push Hypertrophy A', 'Chest & Shoulders', 1, 1,
      'Focus on slow eccentric tempo and chest fly squeeze.',
      JSON.stringify([
        { exerciseId: '0025', name: 'Barbell Bench Press', sets: 4, reps: '8-10', restSeconds: 120 },
        { exerciseId: '0047', name: 'Incline Dumbbell Press', sets: 3, reps: '10-12', restSeconds: 90 },
        { exerciseId: '0085', name: 'Cable Lateral Raise', sets: 4, reps: '12-15', restSeconds: 60 },
        { exerciseId: '0102', name: 'Triceps Rope Pushdown', sets: 3, reps: '12-15', restSeconds: 60 }
      ]),
      now
    );
    insertTemplate.run(
      'tpl_pull_a', 'system', 'PPL — Pull Lat Thickness A', 'Back & Biceps', 1, 1,
      'Initiate pull from the scapula, drive elbows downwards.',
      JSON.stringify([
        { exerciseId: '0027', name: 'Barbell Deadlift', sets: 4, reps: '5', restSeconds: 180 },
        { exerciseId: '0150', name: 'Wide-Grip Lat Pulldown', sets: 4, reps: '8-12', restSeconds: 90 },
        { exerciseId: '0180', name: 'Seated Cable Row', sets: 3, reps: '10-12', restSeconds: 90 },
        { exerciseId: '0210', name: 'Incline Dumbbell Curl', sets: 3, reps: '10-12', restSeconds: 60 }
      ]),
      now
    );
  }

  // 4. Exercises Seed from OpenGym catalogue
  const exerciseCount = db.prepare('SELECT count(*) as count FROM exercises').get().count;
  if (exerciseCount === 0) {
    const cataloguePath = path.resolve(__dirname, '../../tp1/assets/data/opengym_catalogue.json');
    if (fs.existsSync(cataloguePath)) {
      try {
        const raw = fs.readFileSync(cataloguePath, 'utf8').replace(/^\uFEFF/, '');
        const rows = JSON.parse(raw);
        const byId = new Map(rows.map(r => [r.id, r]));

        function resolve(row, seen = new Set()) {
          const id = row.id;
          if (seen.has(id)) return row;
          seen.add(id);
          if (row.name) return row;
          const parent = byId.get(row.variantOf);
          if (!parent) return row;
          return { ...resolve(parent, seen), ...row };
        }

        const insertEx = db.prepare(`
          INSERT OR IGNORE INTO exercises (
            id, name, category, equipment, primary_muscle, secondary_muscles,
            difficulty, suggested_sets, suggested_reps, rest_seconds, instructions,
            description, media_url, media_type, is_published, is_featured, source,
            created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);

        const now = new Date().toISOString();
        const seenNames = new Set();
        let inserted = 0;

        for (const r of rows) {
          const resolved = resolve(r);
          const name = resolved.name?.trim();
          if (!name || seenNames.has(name.toLowerCase())) continue;
          seenNames.add(name.toLowerCase());

          const category = resolved.category || resolved.target || resolved.bodyPart || 'Full Body';
          const equipment = resolved.equipment || 'Bodyweight';
          const primaryMuscle = resolved.target || resolved.bodyPart || category;
          const secondary = JSON.stringify(resolved.secondaryMuscles || []);
          const instructions = JSON.stringify(resolved.instructions || []);
          const desc = resolved.description || `Comprehensive strength training movement targeting the ${primaryMuscle}.`;

          insertEx.run(
            resolved.id || `ex_${inserted}`,
            name,
            category.charAt(0).toUpperCase() + category.slice(1),
            equipment.charAt(0).toUpperCase() + equipment.slice(1),
            primaryMuscle.charAt(0).toUpperCase() + primaryMuscle.slice(1),
            secondary,
            'Intermediate',
            3,
            '8-12',
            90,
            instructions,
            desc,
            resolved.mediaUrl || null,
            resolved.mediaType || 'diagram',
            1,
            inserted < 10 ? 1 : 0,
            'opengym',
            now,
            now
          );
          inserted++;
        }
        console.log(`[Database] Successfully seeded ${inserted} exercises into SQLite.`);
      } catch (err) {
        console.error('[Database] Error seeding exercises:', err);
      }
    }
  }
}

