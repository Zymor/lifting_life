import React, { useState, useEffect } from 'react';
import { api } from '../api';

export default function AuditLogsTab() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  const [limit, setLimit] = useState(50);

  const loadLogs = async () => {
    try {
      setLoading(true);
      setError('');
      const data = await api.getAuditLogs({ limit, action: actionFilter });
      setLogs(data.logs || []);
    } catch (err) {
      setError(err.message || 'Failed to fetch audit trails.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadLogs();
  }, [actionFilter, limit]);

  return (
    <div className="tab-pane">
      <div className="tab-header">
        <div>
          <h2>Security Audit Trail & Compliance Log</h2>
          <p className="tab-subtitle">Immutable operational logs tracking all administrative actions, logins, status changes, and catalog updates.</p>
        </div>
        <button className="btn btn-secondary" onClick={loadLogs}>↻ Refresh Logs</button>
      </div>

      {error && <div className="alert error">{error}</div>}

      <div className="filter-bar" style={{ display: 'flex', gap: '1rem', alignItems: 'center', marginBottom: '1.5rem' }}>
        <input
          type="text"
          placeholder="Filter by action (e.g., USER_SUSPEND, EXERCISE_CREATE)..."
          value={actionFilter}
          onChange={(e) => setActionFilter(e.target.value)}
          style={{ flex: 1, padding: '0.65rem 0.9rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--bg-input)', color: 'var(--text)' }}
        />
        <select
          value={limit}
          onChange={(e) => setLimit(Number(e.target.value))}
          style={{ padding: '0.65rem 0.9rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--bg-input)', color: 'var(--text)' }}
        >
          <option value="25">Show 25</option>
          <option value="50">Show 50</option>
          <option value="100">Show 100</option>
          <option value="200">Show 200</option>
        </select>
      </div>

      <div className="card">
        {loading ? (
          <div className="loading-spinner">Retrieving security audit log entries...</div>
        ) : logs.length === 0 ? (
          <p style={{ color: 'var(--text-muted)', padding: '1rem 0' }}>No log entries found matching criteria.</p>
        ) : (
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Timestamp (UTC)</th>
                  <th>Action Event</th>
                  <th>Admin Actor</th>
                  <th>Target Resource</th>
                  <th>IP Address</th>
                  <th>Event Details</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log.id}>
                    <td style={{ fontSize: '0.85rem', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {new Date(log.created_at).toLocaleString()}
                    </td>
                    <td>
                      <span className={`badge ${
                        log.action.includes('SUSPEND') || log.action.includes('DELETE') 
                          ? 'badge-danger' 
                          : log.action.includes('CREATE') || log.action.includes('UPDATE') 
                          ? 'badge-info' 
                          : 'badge-success'
                      }`}>
                        {log.action}
                      </span>
                    </td>
                    <td style={{ fontWeight: 600 }}>{log.admin_email || 'System'}</td>
                    <td>
                      {log.target_type ? (
                        <span style={{ fontSize: '0.85rem' }}>
                          <code>{log.target_type}</code> #{log.target_id?.slice?.(0, 8) || log.target_id}
                        </span>
                      ) : '—'}
                    </td>
                    <td style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>{log.ip_address || '127.0.0.1'}</td>
                    <td style={{ fontSize: '0.85rem', maxWidth: '350px' }}>
                      {log.details ? (
                        <pre style={{ margin: 0, padding: '0.2rem 0.4rem', fontSize: '0.78rem', background: 'var(--bg-input)', borderRadius: '4px', overflowX: 'auto' }}>
                          {typeof log.details === 'object' ? JSON.stringify(log.details) : log.details}
                        </pre>
                      ) : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

