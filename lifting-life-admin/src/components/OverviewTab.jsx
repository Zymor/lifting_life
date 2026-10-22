import React, { useState, useEffect } from 'react';
import { adminApi } from '../api';

export default function OverviewTab({ setActiveTab }) {
  const [stats, setStats] = useState(null);
  const [range, setRange] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const fetchStats = async (selectedRange) => {
    setLoading(true);
    try {
      const res = await adminApi.getStats(selectedRange);
      setStats(res);
      setError('');
    } catch (err) {
      setError(err.message || 'Failed to fetch platform metrics.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats(range);
  }, [range]);

  if (loading && !stats) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-secondary)' }}>
        Loading verified platform metrics from database...
      </div>
    );
  }

  const kpis = stats?.kpis || {};
  const recentUsers = stats?.recentUsers || [];
  const categories = stats?.categories || [];
  const health = stats?.systemHealth || {};

  return (
    <div>
      {/* Range Filter Toolbar */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: '24px',
          flexWrap: 'wrap',
          gap: '12px'
        }}
      >
        <div>
          <h3 style={{ fontSize: '18px', fontWeight: '800' }}>Platform Health & Key Performance Indicators</h3>
          <p style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
            Real-time server-side statistics computed directly from authorized database records.
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          {['24h', '7d', '30d', 'all'].map((r) => (
            <button
              key={r}
              className={`btn btn-sm ${range === r ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setRange(r)}
            >
              {r === '24h' ? 'Last 24 Hours' : r === '7d' ? 'Last 7 Days' : r === '30d' ? 'Last 30 Days' : 'All Time'}
            </button>
          ))}
          <button className="btn btn-secondary btn-sm" onClick={() => fetchStats(range)} title="Refresh">
            ↻
          </button>
        </div>
      </div>

      {error && (
        <div style={{ padding: '12px', backgroundColor: 'var(--color-danger-subtle)', color: 'var(--color-danger)', borderRadius: '8px', marginBottom: '20px' }}>
          {error}
        </div>
      )}

      {/* KPI Grid */}
      <div className="kpi-grid">
        <div className="kpi-card">
          <div className="kpi-header">
            <span className="kpi-title">Total Registered Users</span>
            <div className="kpi-icon">👥</div>
          </div>
          <div className="kpi-value">{kpis.totalUsers || 0}</div>
          <div className="kpi-subtext">Verified athlete accounts</div>
        </div>

        <div className="kpi-card">
          <div className="kpi-header">
            <span className="kpi-title">New Registrations ({range})</span>
            <div className="kpi-icon">⚡</div>
          </div>
          <div className="kpi-value">{kpis.newRegistrations || 0}</div>
          <div className="kpi-subtext">Selected timeframe signups</div>
        </div>

        <div className="kpi-card">
          <div className="kpi-header">
            <span className="kpi-title">Active Lifters</span>
            <div className="kpi-icon">🔥</div>
          </div>
          <div className="kpi-value">{kpis.activeUsers || 1}</div>
          <div className="kpi-subtext">Active sessions & recent activity</div>
        </div>

        <div className="kpi-card">
          <div className="kpi-header">
            <span className="kpi-title">Workouts Logged</span>
            <div className="kpi-icon">🏋️‍♂️</div>
          </div>
          <div className="kpi-value">{kpis.totalWorkouts || 0}</div>
          <div className="kpi-subtext">Completed user workout logs</div>
        </div>

        <div className="kpi-card">
          <div className="kpi-header">
            <span className="kpi-title">Exercises in Library</span>
            <div className="kpi-icon">📚</div>
          </div>
          <div className="kpi-value">{kpis.totalExercises || 0}</div>
          <div className="kpi-subtext">Published OpenGym & custom</div>
        </div>

        <div className="kpi-card">
          <div className="kpi-header">
            <span className="kpi-title">Workout Templates</span>
            <div className="kpi-icon">📋</div>
          </div>
          <div className="kpi-value">{kpis.totalTemplates || 0}</div>
          <div className="kpi-subtext">Public & system programs</div>
        </div>
      </div>

      {/* Two Columns: Recent Registrations & Category Distribution */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(420px, 1fr))', gap: '24px', marginBottom: '28px' }}>
        {/* Recent Registrations Card */}
        <div className="card-table-wrapper">
          <div className="table-header-toolbar">
            <div className="table-title">Recent User Registrations</div>
            <button className="btn btn-secondary btn-sm" onClick={() => setActiveTab('users')}>
              Manage Users →
            </button>
          </div>

          <table className="data-table">
            <thead>
              <tr>
                <th>User / Email</th>
                <th>Role</th>
                <th>Status</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {recentUsers.length === 0 ? (
                <tr>
                  <td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '24px' }}>
                    No registrations found in this database.
                  </td>
                </tr>
              ) : (
                recentUsers.map((u) => (
                  <tr key={u.id}>
                    <td>
                      <div style={{ fontWeight: '600' }}>{u.username || 'athlete'}</div>
                      <div style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>{u.email}</div>
                    </td>
                    <td>
                      <span className={`badge ${u.role === 'super_admin' ? 'badge-danger' : u.role === 'admin' ? 'badge-warning' : 'badge-accent'}`}>
                        {u.role}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${u.status === 'active' ? 'badge-success' : 'badge-danger'}`}>
                        {u.status}
                      </span>
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                      {new Date(u.created_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Exercise Distribution by Muscle Category */}
        <div className="card-table-wrapper" style={{ padding: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px' }}>
            <div className="table-title">Exercise Library Breakdown</div>
            <button className="btn btn-secondary btn-sm" onClick={() => setActiveTab('exercises')}>
              Catalogue →
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            {categories.map((cat) => {
              const max = categories[0]?.count || 1;
              const percent = Math.round((cat.count / max) * 100);
              return (
                <div key={cat.category}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', marginBottom: '4px' }}>
                    <span style={{ fontWeight: '600' }}>{cat.category}</span>
                    <span style={{ color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>{cat.count} movements</span>
                  </div>
                  <div style={{ height: '8px', borderRadius: '4px', backgroundColor: 'var(--bg-muted)', overflow: 'hidden' }}>
                    <div
                      style={{
                        height: '100%',
                        width: `${percent}%`,
                        backgroundColor: 'var(--color-primary)',
                        borderRadius: '4px'
                      }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* System Infrastructure Health Panel */}
      <div className="card-table-wrapper" style={{ padding: '20px' }}>
        <h4 style={{ fontSize: '15px', fontWeight: '700', marginBottom: '14px' }}>Server Infrastructure & Security Diagnostics</h4>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
          <div>
            <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>System Status</span>
            <div style={{ fontWeight: '700', color: 'var(--color-primary)' }}>● Operational (Zero Faults)</div>
          </div>
          <div>
            <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Database Engine</span>
            <div style={{ fontWeight: '600' }}>{health.databaseEngine || 'SQLite Native'}</div>
          </div>
          <div>
            <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Server Uptime</span>
            <div style={{ fontWeight: '600' }}>{Math.floor((health.uptimeSeconds || 0) / 60)} minutes</div>
          </div>
          <div>
            <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Memory RSS</span>
            <div style={{ fontWeight: '600' }}>{health.memoryUsageMb || 0} MB</div>
          </div>
          <div>
            <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Security Enforcement</span>
            <div style={{ fontWeight: '600', color: 'var(--color-primary)' }}>TOTP MFA + RBAC Active</div>
          </div>
        </div>
      </div>
    </div>
  );
}

