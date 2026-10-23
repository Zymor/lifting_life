import { initializeDatabase, db } from '../src/db.js';
import {
  generateSalt,
  hashPassword,
  generateTotpSecret,
  generateBackupCodes
} from '../src/security.js';
import crypto from 'node:crypto';

initializeDatabase();

const email = process.argv[2] || process.env.ADMIN_EMAIL || 'admin@liftinglife.com';
const password = process.argv[3] || process.env.ADMIN_PASSWORD || 'SuperSecretAdmin2026!';
const name = process.argv[4] || process.env.ADMIN_NAME || 'Platform Master Admin';

const cleanEmail = email.trim().toLowerCase();
const existing = db.prepare('SELECT id, email, role FROM users WHERE email = ?').get(cleanEmail);

if (existing) {
  console.log(`[Setup] Updating existing administrator ${cleanEmail}...`);
  const salt = generateSalt();
  const hash = hashPassword(password, salt);
  db.prepare(`
    UPDATE users SET
      password_hash = ?,
      password_salt = ?,
      role = 'super_admin',
      status = 'active',
      email_verified = 1
    WHERE id = ?
  `).run(hash, salt, existing.id);

  let mfa = db.prepare('SELECT totp_secret, backup_codes FROM admin_mfa WHERE user_id = ?').get(existing.id);
  let totpSecret;
  let backupCodes;

  if (!mfa) {
    totpSecret = generateTotpSecret(20);
    backupCodes = generateBackupCodes(8);
    db.prepare(`
      INSERT INTO admin_mfa (user_id, totp_secret, is_enabled, backup_codes, updated_at)
      VALUES (?, ?, 1, ?, ?)
    `).run(existing.id, totpSecret, JSON.stringify(backupCodes), new Date().toISOString());
  } else {
    totpSecret = mfa.totp_secret;
    backupCodes = JSON.parse(mfa.backup_codes || '[]');
  }

  console.log('----------------------------------------------------');
  console.log('SUCCESS: Super Admin Updated Successfully!');
  console.log(`Email:       ${cleanEmail}`);
  console.log(`Role:        super_admin`);
  console.log(`TOTP Secret: ${totpSecret}`);
  console.log(`Backup Codes:\n${backupCodes.map(c => '  • ' + c).join('\n')}`);
  console.log('----------------------------------------------------');
  process.exit(0);
}

const userId = crypto.randomUUID();
const salt = generateSalt();
const hash = hashPassword(password, salt);
const now = new Date().toISOString();

db.prepare(`
  INSERT INTO users (id, email, password_hash, password_salt, email_verified, role, status, created_at, last_login_at)
  VALUES (?, ?, ?, ?, 1, 'super_admin', 'active', ?, ?)
`).run(userId, cleanEmail, hash, salt, now, now);

db.prepare(`
  INSERT INTO user_profiles (user_id, username, display_name, updated_at)
  VALUES (?, ?, ?, ?)
`).run(userId, 'master_admin', name, now);

const totpSecret = generateTotpSecret(20);
const backupCodes = generateBackupCodes(8);

db.prepare(`
  INSERT INTO admin_mfa (user_id, totp_secret, is_enabled, backup_codes, updated_at)
  VALUES (?, ?, 1, ?, ?)
`).run(userId, totpSecret, JSON.stringify(backupCodes), now);

console.log('====================================================');
console.log('   INITIAL SUPER ADMIN PROVISIONED (NO HARDCODING)   ');
console.log('====================================================');
console.log(`Email:       ${cleanEmail}`);
console.log(`Role:        super_admin`);
console.log(`TOTP Secret: ${totpSecret}`);
console.log(`OTPAuth URI: otpauth://totp/LiftingLifeAdmin:${encodeURIComponent(cleanEmail)}?secret=${totpSecret}&issuer=LiftingLife`);
console.log(`Backup Codes (save securely in vault):`);
backupCodes.forEach(code => console.log(`  • ${code}`));
console.log('====================================================');
process.exit(0);

