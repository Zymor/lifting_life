import React, { useState, useEffect } from 'react';
import { adminApi } from '../api';

export default function SettingsTab({ currentAdmin }) {
  const [settings, setSettings] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Form states
  const [announcement, setAnnouncement] = useState({ title: '', message: '', isActive: true });
  const [maintenance, setMaintenance] = useState({ enabled: false, message: '' });
  const [flags, setFlags] = useState({
    enableLeaderboard: true,
    enableCommunityFeed: true,
    enableBeta3DViewer: true,
    enablePlateCalculator: true,
    requireMFAForAdmins: true
  });

  const fetchSettings = async () => {
    setLoading(true);
    try {
      const res = await adminApi.getSettings();
      setSettings(res.settings);
      if (res.settings.announcement) setAnnouncement(res.settings.announcement);
      if (res.settings.maintenance_mode) setMaintenance(res.settings.maintenance_mode);
      if (res.settings.feature_flags) setFlags(res.settings.feature_flags);
    } catch (err) {
      setError(err.message || 'Failed to fetch settings.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSettings();
  }, []);

  const handleSaveAnnouncement = async (e) => {
    e.preventDefault();
    try {
      await adminApi.updateSetting('announcement', announcement);
      setSuccess('Platform announcement updated.');
    } catch (err) {
      setError(err.message || 'Failed to update announcement.');
    }
  };

  const handleSaveMaintenance = async (e) => {
    e.preventDefault();
    try {
      await adminApi.updateSetting('maintenance_mode', maintenance);
      setSuccess('Maintenance mode settings updated.');
    } catch (err) {
      setError(err.message || 'Failed to update maintenance settings.');
    }
  };

  const handleToggleFlag = async (flagKey) => {
    const updated = { ...flags, [flagKey]: !flags[flagKey] };
    setFlags(updated);
    try {
      await adminApi.updateSetting('feature_flags', updated);
      setSuccess(`Feature flag "${flagKey}" updated.`);
    } catch (err) {
      setError(err.message || 'Failed to update feature flag.');
      setFlags(flags); // revert
    }
  };

  if (loading && !settings) {
    return <div style={{ padding: '36px', textAlign: 'center', color: 'var(--text-muted)' }}>Loading platform configuration...</div>;
  }

  const isSuperAdmin = currentAdmin?.role === 'super_admin';

  return (
    <div style={{ maxWidth: '900px' }}>
      <div style={{ marginBottom: '24px' }}>
        <h3 style={{ fontSize: '18px', fontWeight: '800' }}>Platform Settings & Infrastructure Controls</h3>
        <p style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
          Manage global application notices, system maintenance switches, and runtime feature flags.
        </p>
      </div>

      {success && (
        <div style={{ padding: '12px', backgroundColor: 'var(--color-primary-subtle)', color: 'var(--color-primary)', borderRadius: '8px', marginBottom: '16px' }}>
          ✓ {success}
        </div>
      )}

      {error && (
        <div style={{ padding: '12px', backgroundColor: 'var(--color-danger-subtle)', color: 'var(--color-danger)', borderRadius: '8px', marginBottom: '16px' }}>
          ✕ {error}
        </div>
      )}

      {/* 1. Global Announcement Banner */}
      <div className="card-table-wrapper" style={{ padding: '24px', marginBottom: '24px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
          <div>
            <h4 style={{ fontSize: '15px', fontWeight: '700' }}>Platform Announcement Banner</h4>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Broadcasted in the header of the Lifting Life user application.</p>
          </div>
          <span className={`badge ${announcement.isActive ? 'badge-success' : 'badge-warning'}`}>
            {announcement.isActive ? 'Active on App' : 'Disabled'}
          </span>
        </div>

        <form onSubmit={handleSaveAnnouncement} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Announcement Title</label>
            <input
              type="text"
              className="input"
              value={announcement.title}
              onChange={(e) => setAnnouncement({ ...announcement, title: e.target.value })}
              required
            />
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Announcement Message</label>
            <textarea
              className="textarea"
              rows="3"
              value={announcement.message}
              onChange={(e) => setAnnouncement({ ...announcement, message: e.target.value })}
              required
            />
          </div>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={announcement.isActive}
                onChange={(e) => setAnnouncement({ ...announcement, isActive: e.target.checked })}
              />
              <span style={{ fontSize: '13px' }}>Display notice on athlete dashboard</span>
            </label>

            <button type="submit" className="btn btn-primary btn-sm">Save Announcement</button>
          </div>
        </form>
      </div>

      {/* 2. Maintenance Mode Controls */}
      <div className="card-table-wrapper" style={{ padding: '24px', marginBottom: '24px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
          <div>
            <h4 style={{ fontSize: '15px', fontWeight: '700' }}>System Maintenance Mode</h4>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Temporarily restrict user workouts for database migrations or upgrades.</p>
          </div>
          <span className={`badge ${maintenance.enabled ? 'badge-danger' : 'badge-success'}`}>
            {maintenance.enabled ? 'Maintenance ON' : 'Live & Accepting Traffic'}
          </span>
        </div>

        <form onSubmit={handleSaveMaintenance} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>User-Facing Downtime Notice</label>
            <input
              type="text"
              className="input"
              placeholder="System is currently undergoing scheduled performance tuning."
              value={maintenance.message}
              onChange={(e) => setMaintenance({ ...maintenance, message: e.target.value })}
            />
          </div>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={maintenance.enabled}
                onChange={(e) => setMaintenance({ ...maintenance, enabled: e.target.checked })}
              />
              <span style={{ fontSize: '13px', fontWeight: maintenance.enabled ? '700' : '400', color: maintenance.enabled ? 'var(--color-danger)' : 'inherit' }}>
                Activate Maintenance Lockout Mode
              </span>
            </label>

            <button type="submit" className="btn btn-secondary btn-sm">Update Maintenance Mode</button>
          </div>
        </form>
      </div>

      {/* 3. Runtime Feature Flags */}
      <div className="card-table-wrapper" style={{ padding: '24px', marginBottom: '24px' }}>
        <h4 style={{ fontSize: '15px', fontWeight: '700', marginBottom: '6px' }}>Dynamic Feature Flags</h4>
        <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '18px' }}>
          Instantly enable or disable capabilities in the Lifting Life mobile and web client without deploying new code.
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {[
            { key: 'enableLeaderboard', label: 'Athlete Leaderboards & Rankings', desc: 'Allows lifters to view national and global PR rankings.' },
            { key: 'enableCommunityFeed', label: 'Community Social Feed & Tips', desc: 'Public feed displaying training cues and community updates.' },
            { key: 'enableBeta3DViewer', label: 'Interactive 3D Biomechanics Viewer', desc: 'Hardware-accelerated skeletal movement renderer in exercise detail.' },
            { key: 'enablePlateCalculator', label: 'Olympic Barbell Plate Sleeve Calculator', desc: 'Visual plate loading assistant for barbell and plate-loaded exercises.' },
            { key: 'requireMFAForAdmins', label: 'Enforce Mandatory 2FA for Administrators', desc: 'Requires TOTP code verification on every administrative session.' }
          ].map(f => (
            <div key={f.key} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', backgroundColor: 'var(--bg-card-hover)', borderRadius: '8px' }}>
              <div>
                <div style={{ fontWeight: '600', fontSize: '13.5px' }}>{f.label}</div>
                <div style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>{f.desc}</div>
              </div>
              <button
                className={`btn btn-sm ${flags[f.key] ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => handleToggleFlag(f.key)}
              >
                {flags[f.key] ? 'Enabled' : 'Disabled'}
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Security Notice */}
      <div style={{ padding: '16px', borderRadius: '10px', backgroundColor: 'var(--bg-muted)', border: '1px solid var(--border-color)', fontSize: '12px', color: 'var(--text-muted)' }}>
        🔒 <strong>OWASP Compliance Notice:</strong> Critical infrastructure secrets, JWT signing keys, and database credentials are kept strictly in server-side environment variables and cannot be accessed or altered from admin settings.
      </div>
    </div>
  );
}

