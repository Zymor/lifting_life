import React, { useState, useEffect } from 'react';
import { adminApi } from '../api';

export default function UsersTab({ currentAdmin }) {
  const [users, setUsers] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, totalPages: 1, totalCount: 0 });
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [roleFilter, setRoleFilter] = useState('all');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Modals
  const [selectedUser, setSelectedUser] = useState(null);
  const [suspendModalUser, setSuspendModalUser] = useState(null);
  const [suspendReason, setSuspendReason] = useState('');
  const [roleModalUser, setRoleModalUser] = useState(null);
  const [newRole, setNewRole] = useState('user');
  const [recoveryModalData, setRecoveryModalData] = useState(null);
  const [deleteModalUser, setDeleteModalUser] = useState(null);

  const fetchUsers = async (page = 1) => {
    setLoading(true);
    setError('');
    try {
      const res = await adminApi.getUsers({
        search,
        status: statusFilter,
        role: roleFilter,
        page,
        limit: 15
      });
      setUsers(res.users);
      setPagination(res.pagination);
    } catch (err) {
      setError(err.message || 'Failed to fetch users list.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers(1);
  }, [statusFilter, roleFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    fetchUsers(1);
  };

  const handleStatusChange = async () => {
    if (!suspendModalUser) return;
    const targetStatus = suspendModalUser.status === 'active' ? 'suspended' : 'active';
    try {
      await adminApi.updateUserStatus(suspendModalUser.id, targetStatus, suspendReason);
      setSuccess(`Account status for ${suspendModalUser.email} changed to ${targetStatus}.`);
      setSuspendModalUser(null);
      setSuspendReason('');
      fetchUsers(pagination.page);
    } catch (err) {
      setError(err.message || 'Failed to update user status.');
    }
  };

  const handleRoleChange = async () => {
    if (!roleModalUser) return;
    try {
      await adminApi.updateUserRole(roleModalUser.id, newRole);
      setSuccess(`Role for ${roleModalUser.email} updated to ${newRole}.`);
      setRoleModalUser(null);
      fetchUsers(pagination.page);
    } catch (err) {
      setError(err.message || 'Failed to update role.');
    }
  };

  const handleGenerateRecovery = async (user) => {
    try {
      const res = await adminApi.generateUserRecovery(user.id);
      setRecoveryModalData(res);
    } catch (err) {
      setError(err.message || 'Failed to generate recovery token.');
    }
  };

  const handleDeleteUser = async () => {
    if (!deleteModalUser) return;
    try {
      await adminApi.deleteUser(deleteModalUser.id);
      setSuccess(`User account ${deleteModalUser.email} permanently purged.`);
      setDeleteModalUser(null);
      fetchUsers(pagination.page);
    } catch (err) {
      setError(err.message || 'Failed to delete user.');
    }
  };

  const isSuperAdmin = currentAdmin?.role === 'super_admin';

  return (
    <div>
      {/* Search and Filters Bar */}
      <div className="card-table-wrapper" style={{ padding: '16px 20px', marginBottom: '20px' }}>
        <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}>
          <div style={{ flex: '1', minWidth: '240px' }}>
            <input
              type="text"
              className="input"
              placeholder="Search by email, username, or display name..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div style={{ width: '150px' }}>
            <select
              className="select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="all">Status: All</option>
              <option value="active">Active Only</option>
              <option value="suspended">Suspended Only</option>
            </select>
          </div>

          <div style={{ width: '160px' }}>
            <select
              className="select"
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
            >
              <option value="all">Role: All</option>
              <option value="user">Regular User</option>
              <option value="support_staff">Support Staff</option>
              <option value="content_manager">Content Manager</option>
              <option value="admin">Admin</option>
              <option value="super_admin">Super Admin</option>
            </select>
          </div>

          <button type="submit" className="btn btn-primary btn-sm">
            Search
          </button>
          <button
            type="button"
            className="btn btn-secondary btn-sm"
            onClick={() => {
              setSearch('');
              setStatusFilter('all');
              setRoleFilter('all');
            }}
          >
            Clear
          </button>
        </form>
      </div>

      {success && (
        <div style={{ padding: '12px', backgroundColor: 'var(--color-primary-subtle)', color: 'var(--color-primary)', borderRadius: '8px', marginBottom: '16px', display: 'flex', justifyContent: 'space-between' }}>
          <span>✓ {success}</span>
          <button onClick={() => setSuccess('')} style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer' }}>✕</button>
        </div>
      )}

      {error && (
        <div style={{ padding: '12px', backgroundColor: 'var(--color-danger-subtle)', color: 'var(--color-danger)', borderRadius: '8px', marginBottom: '16px', display: 'flex', justifyContent: 'space-between' }}>
          <span>✕ {error}</span>
          <button onClick={() => setError('')} style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer' }}>✕</button>
        </div>
      )}

      {/* Users Table */}
      <div className="card-table-wrapper">
        <div className="table-header-toolbar">
          <div className="table-title">
            Registered Athlete Accounts ({pagination.totalCount})
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
            Page {pagination.page} of {pagination.totalPages || 1}
          </div>
        </div>

        <table className="data-table">
          <thead>
            <tr>
              <th>Athlete</th>
              <th>Email</th>
              <th>Role</th>
              <th>Status</th>
              <th>Workouts</th>
              <th>Registered</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan="7" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  Querying authorized database...
                </td>
              </tr>
            ) : users.length === 0 ? (
              <tr>
                <td colSpan="7" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  No accounts matched your filters.
                </td>
              </tr>
            ) : (
              users.map((u) => (
                <tr key={u.id}>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <div
                        style={{
                          width: '32px',
                          height: '32px',
                          borderRadius: '50%',
                          backgroundColor: 'var(--bg-muted)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: '12px',
                          fontWeight: '700',
                          color: 'var(--color-primary)'
                        }}
                      >
                        {(u.username || u.email)[0].toUpperCase()}
                      </div>
                      <div>
                        <div style={{ fontWeight: '600' }}>{u.display_name || u.username || 'Lifter'}</div>
                        <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>@{u.username || 'unnamed'}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span style={{ fontFamily: 'var(--font-mono)', fontSize: '12.5px' }}>{u.email}</span>
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
                  <td style={{ fontFamily: 'var(--font-mono)', fontSize: '13px' }}>
                    {u.workout_count || 0}
                  </td>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    {new Date(u.created_at).toLocaleDateString()}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: '6px' }}>
                      <button
                        className="btn btn-secondary btn-sm"
                        onClick={() => setSelectedUser(u)}
                        title="View limited details"
                      >
                        Details
                      </button>

                      {u.role !== 'super_admin' && (
                        <button
                          className={`btn btn-sm ${u.status === 'active' ? 'btn-danger' : 'btn-primary'}`}
                          onClick={() => setSuspendModalUser(u)}
                        >
                          {u.status === 'active' ? 'Suspend' : 'Reactivate'}
                        </button>
                      )}

                      {isSuperAdmin && (
                        <button
                          className="btn btn-secondary btn-sm"
                          onClick={() => {
                            setRoleModalUser(u);
                            setNewRole(u.role);
                          }}
                          title="Change Role"
                        >
                          Role
                        </button>
                      )}

                      <button
                        className="btn btn-secondary btn-sm"
                        onClick={() => handleGenerateRecovery(u)}
                        title="Initiate approved account recovery"
                      >
                        Recovery
                      </button>

                      {u.role !== 'super_admin' && (
                        <button
                          className="btn btn-danger btn-sm"
                          onClick={() => setDeleteModalUser(u)}
                          title="Delete user account"
                        >
                          🗑️
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>

        {/* Pagination Toolbar */}
        <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button
            className="btn btn-secondary btn-sm"
            disabled={pagination.page <= 1}
            onClick={() => fetchUsers(pagination.page - 1)}
          >
            ← Previous
          </button>
          <span style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
            Page {pagination.page} of {pagination.totalPages || 1}
          </span>
          <button
            className="btn btn-secondary btn-sm"
            disabled={pagination.page >= pagination.totalPages}
            onClick={() => fetchUsers(pagination.page + 1)}
          >
            Next →
          </button>
        </div>
      </div>

      {/* Modal: View Limited Account Details */}
      {selectedUser && (
        <div className="modal-backdrop" onClick={() => setSelectedUser(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Athlete Account Details</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setSelectedUser(null)}>✕</button>
            </div>
            <div className="modal-body">
              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>User ID (UUID)</span>
                  <div style={{ fontFamily: 'var(--font-mono)', fontSize: '13px' }}>{selectedUser.id}</div>
                </div>
                <div>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Email Address</span>
                  <div style={{ fontWeight: '600' }}>{selectedUser.email}</div>
                </div>
                <div>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Username</span>
                  <div>@{selectedUser.username || 'unnamed'}</div>
                </div>
                <div>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Display Name</span>
                  <div>{selectedUser.display_name || selectedUser.username}</div>
                </div>
                <div>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Assigned Platform Role</span>
                  <div><span className="badge badge-accent">{selectedUser.role}</span></div>
                </div>
                <div>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Account Status</span>
                  <div><span className={`badge ${selectedUser.status === 'active' ? 'badge-success' : 'badge-danger'}`}>{selectedUser.status}</span></div>
                </div>
                <div>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Registration Date</span>
                  <div>{new Date(selectedUser.created_at).toLocaleString()}</div>
                </div>
                <div>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Last Activity</span>
                  <div>{selectedUser.last_login_at ? new Date(selectedUser.last_login_at).toLocaleString() : 'Never'}</div>
                </div>
                <div style={{ padding: '12px', backgroundColor: 'var(--bg-muted)', borderRadius: '8px', fontSize: '12px', color: 'var(--text-muted)' }}>
                  🔒 <strong>Privacy Assurance:</strong> User passwords, workout weights, and personal journals are strictly protected. Passwords and salted hashes are never displayed.
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setSelectedUser(null)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Suspend / Reactivate Confirmation */}
      {suspendModalUser && (
        <div className="modal-backdrop" onClick={() => setSuspendModalUser(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{suspendModalUser.status === 'active' ? 'Confirm Account Suspension' : 'Confirm Account Reactivation'}</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setSuspendModalUser(null)}>✕</button>
            </div>
            <div className="modal-body">
              <p style={{ marginBottom: '16px' }}>
                Are you sure you want to {suspendModalUser.status === 'active' ? 'suspend' : 'reactivate'} the account for <strong>{suspendModalUser.email}</strong>?
              </p>
              {suspendModalUser.status === 'active' && (
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', marginBottom: '6px' }}>
                    Reason for Suspension (recorded in immutable audit log)
                  </label>
                  <input
                    type="text"
                    className="input"
                    placeholder="e.g. Inappropriate behavior, spam, suspicious activity"
                    value={suspendReason}
                    onChange={(e) => setSuspendReason(e.target.value)}
                  />
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setSuspendModalUser(null)}>Cancel</button>
              <button
                className={`btn ${suspendModalUser.status === 'active' ? 'btn-danger' : 'btn-primary'}`}
                onClick={handleStatusChange}
              >
                Confirm {suspendModalUser.status === 'active' ? 'Suspension' : 'Reactivation'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Change Role */}
      {roleModalUser && (
        <div className="modal-backdrop" onClick={() => setRoleModalUser(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Update Role: {roleModalUser.email}</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setRoleModalUser(null)}>✕</button>
            </div>
            <div className="modal-body">
              <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '6px' }}>
                Select Role (Server-Side RBAC Enforced)
              </label>
              <select className="select" value={newRole} onChange={(e) => setNewRole(e.target.value)}>
                <option value="user">Regular User</option>
                <option value="support_staff">Support Staff (read-only stats)</option>
                <option value="content_manager">Content Manager (exercises & routines)</option>
                <option value="admin">Administrator (full user & content management)</option>
                <option value="super_admin">Super Administrator (full access)</option>
              </select>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setRoleModalUser(null)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleRoleChange}>Apply Role</button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Recovery Code Generated */}
      {recoveryModalData && (
        <div className="modal-backdrop" onClick={() => setRecoveryModalData(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Authorized Recovery Token Generated</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setRecoveryModalData(null)}>✕</button>
            </div>
            <div className="modal-body">
              <p style={{ marginBottom: '14px', fontSize: '13.5px' }}>
                Provide this one-time recovery code to the athlete to verify their identity and reset their password:
              </p>
              <div
                style={{
                  padding: '16px',
                  backgroundColor: 'var(--color-primary-subtle)',
                  border: '1px solid var(--color-primary-border)',
                  borderRadius: '10px',
                  textAlign: 'center',
                  fontFamily: 'var(--font-mono)',
                  fontSize: '24px',
                  fontWeight: '800',
                  letterSpacing: '0.2em',
                  color: 'var(--color-primary)'
                }}
              >
                {recoveryModalData.recoveryCode}
              </div>
              <p style={{ fontSize: '11.5px', color: 'var(--text-muted)', marginTop: '10px' }}>
                Expires at: {new Date(recoveryModalData.expiresAt).toLocaleTimeString()} (Valid for 60 minutes).
              </p>
            </div>
            <div className="modal-footer">
              <button className="btn btn-primary" onClick={() => setRecoveryModalData(null)}>Done</button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Delete User Confirmation */}
      {deleteModalUser && (
        <div className="modal-backdrop" onClick={() => setDeleteModalUser(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Confirm Permanent Account Deletion</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setDeleteModalUser(null)}>✕</button>
            </div>
            <div className="modal-body">
              <p style={{ color: 'var(--color-danger)', fontWeight: '600', marginBottom: '10px' }}>
                ⚠️ Warning: This action cannot be undone.
              </p>
              <p style={{ fontSize: '13.5px', lineHeight: '1.4' }}>
                Permanently delete account <strong>{deleteModalUser.email}</strong>, all associated personal records, and database rows?
              </p>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setDeleteModalUser(null)}>Cancel</button>
              <button className="btn btn-danger" onClick={handleDeleteUser}>Purge Account</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

