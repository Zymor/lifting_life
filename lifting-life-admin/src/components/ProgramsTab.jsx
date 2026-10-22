import React, { useState, useEffect } from 'react';
import { adminApi } from '../api';

export default function ProgramsTab() {
  const [subTab, setSubTab] = useState('programs'); // 'programs' | 'templates'
  const [programs, setPrograms] = useState([]);
  const [templates, setTemplates] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // New Program Modal
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [programForm, setProgramForm] = useState({
    title: '',
    description: '',
    level: 'Intermediate',
    durationWeeks: 8,
    isPublic: true,
    isFeatured: false
  });

  const fetchData = async () => {
    setLoading(true);
    setError('');
    try {
      const [progRes, tplRes] = await Promise.all([
        adminApi.getPrograms(),
        adminApi.getTemplates()
      ]);
      setPrograms(progRes.programs || []);
      setTemplates(tplRes.templates || []);
    } catch (err) {
      setError(err.message || 'Failed to load workout content.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleCreateProgram = async (e) => {
    e.preventDefault();
    try {
      await adminApi.createProgram(programForm);
      setSuccess(`Program "${programForm.title}" published!`);
      setShowCreateModal(false);
      setProgramForm({
        title: '',
        description: '',
        level: 'Intermediate',
        durationWeeks: 8,
        isPublic: true,
        isFeatured: false
      });
      fetchData();
    } catch (err) {
      setError(err.message || 'Failed to create program.');
    }
  };

  const handleDeleteProgram = async (id, title) => {
    if (!window.confirm(`Delete training program "${title}"?`)) return;
    try {
      await adminApi.deleteProgram(id);
      setSuccess(`Program "${title}" deleted.`);
      fetchData();
    } catch (err) {
      setError(err.message || 'Failed to delete program.');
    }
  };

  return (
    <div>
      {/* Switcher & Action bar */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: '20px',
          flexWrap: 'wrap',
          gap: '12px'
        }}
      >
        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            className={`btn btn-sm ${subTab === 'programs' ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => setSubTab('programs')}
          >
            Curated Training Programs ({programs.length})
          </button>
          <button
            className={`btn btn-sm ${subTab === 'templates' ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => setSubTab('templates')}
          >
            Public Workout Templates ({templates.length})
          </button>
        </div>

        {subTab === 'programs' && (
          <button className="btn btn-primary btn-sm" onClick={() => setShowCreateModal(true)}>
            + Create Program
          </button>
        )}
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

      {subTab === 'programs' ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: '20px' }}>
          {programs.map((p) => (
            <div key={p.id} className="kpi-card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '10px' }}>
                  <span className="badge badge-accent">{p.level}</span>
                  {p.isFeatured && <span className="badge badge-warning">★ Featured</span>}
                </div>
                <h4 style={{ fontSize: '16px', fontWeight: '800', marginBottom: '8px' }}>{p.title}</h4>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '1.4', marginBottom: '14px' }}>
                  {p.description}
                </p>
              </div>

              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: 'var(--text-muted)', borderTop: '1px solid var(--border-color)', paddingTop: '12px', marginTop: '12px' }}>
                  <span>Duration: <strong>{p.duration_weeks} Weeks</strong></span>
                  <span>Visibility: <strong>{p.isPublic ? 'Public' : 'Hidden'}</strong></span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '12px' }}>
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={() => handleDeleteProgram(p.id, p.title)}
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="card-table-wrapper">
          <div className="table-header-toolbar">
            <div className="table-title">Public Workout Templates</div>
          </div>
          <table className="data-table">
            <thead>
              <tr>
                <th>Template Name</th>
                <th>Category</th>
                <th>Target Movements</th>
                <th>Visibility</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {templates.map((t) => (
                <tr key={t.id}>
                  <td>
                    <div style={{ fontWeight: '600' }}>{t.name}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{t.notes}</div>
                  </td>
                  <td><span className="badge badge-accent">{t.category}</span></td>
                  <td>
                    <div style={{ fontSize: '12.5px' }}>
                      {(t.exercises || []).map(e => e.name).slice(0, 3).join(', ')}
                      {(t.exercises || []).length > 3 ? ` + ${(t.exercises || []).length - 3} more` : ''}
                    </div>
                  </td>
                  <td>
                    <span className="badge badge-success">Public to All Users</span>
                  </td>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    {new Date(t.created_at).toLocaleDateString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Modal: Create Program */}
      {showCreateModal && (
        <div className="modal-backdrop" onClick={() => setShowCreateModal(false)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Create Public Training Program</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setShowCreateModal(false)}>✕</button>
            </div>
            <form onSubmit={handleCreateProgram}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Program Title</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="e.g. 10-Week Hypertrophy Overload"
                    value={programForm.title}
                    onChange={(e) => setProgramForm({ ...programForm, title: e.target.value })}
                    required
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Description</label>
                  <textarea
                    className="textarea"
                    rows="3"
                    value={programForm.description}
                    onChange={(e) => setProgramForm({ ...programForm, description: e.target.value })}
                    required
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Target Level</label>
                    <select
                      className="select"
                      value={programForm.level}
                      onChange={(e) => setProgramForm({ ...programForm, level: e.target.value })}
                    >
                      <option value="Beginner">Beginner</option>
                      <option value="Intermediate">Intermediate</option>
                      <option value="Advanced">Advanced</option>
                    </select>
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Duration (Weeks)</label>
                    <input
                      type="number"
                      className="input"
                      value={programForm.durationWeeks}
                      onChange={(e) => setProgramForm({ ...programForm, durationWeeks: e.target.value })}
                    />
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '20px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={programForm.isFeatured}
                      onChange={(e) => setProgramForm({ ...programForm, isFeatured: e.target.checked })}
                    />
                    <span style={{ fontSize: '13px' }}>Feature on User Dashboard</span>
                  </label>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowCreateModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Publish Program</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

