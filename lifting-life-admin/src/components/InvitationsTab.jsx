import React, { useState, useEffect } from 'react';
import { api } from '../api';

export default function InvitationsTab() {
  const [invitations, setInvitations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('moderator');
  const [creating, setCreating] = useState(false);
  const [createdInvite, setCreatedInvite] = useState(null);

  const loadInvitations = async () => {
    try {
      setLoading(true);
      setError('');
      const data = await api.getInvitations();
      setInvitations(data.invitations || []);
    } catch (err) {
      setError(err.message || 'Failed to load team invitations.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadInvitations();
  }, []);

  const handleCreateInvite = async (e) => {
    e.preventDefault();
    if (!email) return;
    try {
      setCreating(true);
      setError('');
      const res = await api.createInvitation(email, role);
      setCreatedInvite(res.invitation);
      setEmail('');
      loadInvitations();
    } catch (err) {
      setError(err.message || 'Failed to create invitation.');
    } finally {
      setCreating(false);
    }
  };

  const handleRevoke = async (id) => {
    if (!window.confirm('Are you sure you want to revoke this invitation?')) return;
    try {
      await api.revokeInvitation(id);
      loadInvitations();
    } catch (err) {
      alert(err.message || 'Failed to revoke invitation');
    }
  };

  return (
    <div className="tab-pane">
      <div className="tab-header">
        <div>
          <h2>Staff Invitations & Access Delegation</h2>
          <p className="tab-subtitle">Invite verified team members with defined role-based access control (RBAC).</p>
        </div>
      </div>

      {error && <div className="alert error">{error}</div>}

      {createdInvite && (
        <div className="alert success" style={{ marginBottom: '1.5rem' }}>
          <h4>✓ Invitation Link Generated for {createdInvite.email} ({createdInvite.role})</h4>
          <p style={{ marginTop: '0.4rem', fontSize: '0.85rem' }}>
            Invitation Token: <code>{createdInvite.token}</code> (Expires in 48 hours)
          </p>
          <button 
            className="btn btn-secondary btn-sm" 
            style={{ marginTop: '0.5rem' }}
            onClick={() => {
              navigator.clipboard?.writeText(createdInvite.token);
              alert('Copied token to clipboard!');
            }}
          >
            Copy Token
          </button>
        </div>
      )}

      <div className="card" style={{ marginBottom: '1.5rem' }}>
        <h3 style={{ fontSize: '1.1rem', marginBottom: '1rem' }}>Create New Staff Invite</h3>
        <form onSubmit={handleCreateInvite} style={{ display: 'flex', gap: '0.8rem', alignItems: 'center', flexWrap: 'wrap' }}>
          <input
            type="email"
            placeholder="colleague@liftinglife.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            style={{ flex: '1 1 240px', padding: '0.65rem 0.9rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--bg-input)', color: 'var(--text)' }}
          />
          <select
            value={role}
            onChange={(e) => setRole(e.target.value)}
            style={{ padding: '0.65rem 0.9rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--bg-input)', color: 'var(--text)' }}
          >
            <option value="moderator">Moderator (Content & Catalog)</option>
            <option value="support">Support (User Management)</option>
            <option value="analyst">Analyst (Read-Only Metrics)</option>
            <option value="super_admin">Super Admin (Full System Control)</option>
          </select>
          <button type="submit" className="btn btn-primary" disabled={creating}>
            {creating ? 'Generating...' : '+ Send Invite'}
          </button>
        </form>
      </div>

      <div className="card">
        <h3 style={{ fontSize: '1.1rem', marginBottom: '1rem' }}>Active & Historical Invitations</h3>
        {loading ? (
          <div className="loading-spinner">Loading team access records...</div>
        ) : invitations.length === 0 ? (
          <p style={{ color: 'var(--text-muted)', padding: '1rem 0' }}>No pending invitations. Invite a colleague above.</p>
        ) : (
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Invitee Email</th>
                  <th>Assigned Role</th>
                  <th>Invited By</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th>Expires</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {invitations.map((inv) => (
                  <tr key={inv.id}>
                    <td style={{ fontWeight: 600 }}>{inv.email}</td>
                    <td><span className="badge badge-info">{inv.role}</span></td>
                    <td style={{ color: 'var(--text-muted)' }}>{inv.invited_by_email || 'System'}</td>
                    <td>
                      {inv.accepted_at ? (
                        <span className="badge badge-success">Accepted</span>
                      ) : new Date(inv.expires_at) < new Date() ? (
                        <span className="badge badge-secondary">Expired</span>
                      ) : (
                        <span className="badge badge-warning">Pending</span>
                      )}
                    </td>
                    <td>{new Date(inv.created_at).toLocaleDateString()}</td>
                    <td>{new Date(inv.expires_at).toLocaleDateString()}</td>
                    <td>
                      {!inv.accepted_at && (
                        <button
                          className="btn btn-outline-danger btn-sm"
                          onClick={() => handleRevoke(inv.id)}
                        >
                          Revoke
                        </button>
                      )}
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

