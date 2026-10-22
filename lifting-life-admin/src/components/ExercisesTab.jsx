import React, { useState, useEffect } from 'react';
import { adminApi } from '../api';

export default function ExercisesTab() {
  const [exercises, setExercises] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, totalPages: 1, totalCount: 0 });
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [equipmentFilter, setEquipmentFilter] = useState('all');
  const [publishedFilter, setPublishedFilter] = useState('all');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Modals & Forms
  const [showAddModal, setShowAddModal] = useState(false);
  const [editModalEx, setEditModalEx] = useState(null);
  const [deleteModalEx, setDeleteModalEx] = useState(null);
  const [duplicatesData, setDuplicatesData] = useState(null);

  // Form State
  const initialForm = {
    name: '',
    category: 'Chest',
    equipment: 'Barbell',
    primaryMuscle: 'Pectoralis Major',
    secondaryMuscles: 'Triceps, Anterior Deltoid',
    difficulty: 'Intermediate',
    suggestedSets: 3,
    suggestedReps: '8-12',
    restSeconds: 90,
    instructions: '1. Lie on flat bench with eyes under barbell.\n2. Grip barbell slightly wider than shoulder width.\n3. Lower with controlled eccentric to mid-chest.\n4. Press forcefully upwards to full lockout.',
    description: 'Foundational compound pressing movement for upper body hypertrophy and strength.',
    mediaUrl: '',
    mediaType: 'diagram',
    isFeatured: false
  };
  const [formData, setFormData] = useState(initialForm);

  const categories = [
    'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Forearms',
    'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Core', 'Full Body', 'Cardio'
  ];

  const equipmentList = [
    'Barbell', 'Dumbbell', 'Cable', 'Machine', 'Plate Loaded',
    'Bodyweight', 'Kettlebell', 'Band', 'Smith Machine', 'Cardio Machine'
  ];

  const fetchExercises = async (page = 1) => {
    setLoading(true);
    setError('');
    try {
      const res = await adminApi.getExercises({
        search,
        category: categoryFilter,
        equipment: equipmentFilter,
        published: publishedFilter,
        page,
        limit: 15
      });
      setExercises(res.exercises);
      setPagination(res.pagination);
    } catch (err) {
      setError(err.message || 'Failed to fetch exercise catalogue.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchExercises(1);
  }, [categoryFilter, equipmentFilter, publishedFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    fetchExercises(1);
  };

  const handleCreateExercise = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        ...formData,
        secondaryMuscles: formData.secondaryMuscles.split(',').map(s => s.trim()).filter(Boolean),
        instructions: formData.instructions.split('\n').map(s => s.trim()).filter(Boolean)
      };
      await adminApi.createExercise(payload);
      setSuccess(`Exercise "${formData.name}" added to library successfully!`);
      setShowAddModal(false);
      setFormData(initialForm);
      fetchExercises(1);
    } catch (err) {
      setError(err.message || 'Failed to create exercise.');
    }
  };

  const handleUpdateExercise = async (e) => {
    e.preventDefault();
    if (!editModalEx) return;
    try {
      const payload = {
        ...formData,
        secondaryMuscles: formData.secondaryMuscles.split(',').map(s => s.trim()).filter(Boolean),
        instructions: formData.instructions.split('\n').map(s => s.trim()).filter(Boolean)
      };
      await adminApi.updateExercise(editModalEx.id, payload);
      setSuccess(`Exercise "${formData.name}" updated successfully.`);
      setEditModalEx(null);
      fetchExercises(pagination.page);
    } catch (err) {
      setError(err.message || 'Failed to update exercise.');
    }
  };

  const handleTogglePublish = async (ex) => {
    try {
      await adminApi.togglePublishExercise(ex.id);
      setSuccess(`Exercise "${ex.name}" publication state updated.`);
      fetchExercises(pagination.page);
    } catch (err) {
      setError(err.message || 'Failed to update publication status.');
    }
  };

  const handleDeleteExercise = async () => {
    if (!deleteModalEx) return;
    try {
      await adminApi.deleteExercise(deleteModalEx.id);
      setSuccess(`Exercise "${deleteModalEx.name}" removed.`);
      setDeleteModalEx(null);
      fetchExercises(pagination.page);
    } catch (err) {
      setError(err.message || 'Failed to delete exercise.');
    }
  };

  const handleScanDuplicates = async () => {
    try {
      const res = await adminApi.getExerciseDuplicates();
      setDuplicatesData(res.duplicates);
    } catch (err) {
      setError(err.message || 'Failed to run duplicate detector.');
    }
  };

  const openEditModal = (ex) => {
    setFormData({
      name: ex.name,
      category: ex.category,
      equipment: ex.equipment,
      primaryMuscle: ex.primary_muscle,
      secondaryMuscles: (ex.secondaryMuscles || []).join(', '),
      difficulty: ex.difficulty,
      suggestedSets: ex.suggested_sets,
      suggestedReps: ex.suggested_reps,
      restSeconds: ex.rest_seconds,
      instructions: (ex.instructions || []).join('\n'),
      description: ex.description || '',
      mediaUrl: ex.media_url || '',
      mediaType: ex.media_type || 'diagram',
      isFeatured: ex.isFeatured
    });
    setEditModalEx(ex);
  };

  return (
    <div>
      {/* Top Filter and Actions Bar */}
      <div className="card-table-wrapper" style={{ padding: '16px 20px', marginBottom: '20px' }}>
        <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}>
          <div style={{ flex: '1', minWidth: '220px' }}>
            <input
              type="text"
              className="input"
              placeholder="Search 5,600+ exercises by name or primary muscle..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div style={{ width: '140px' }}>
            <select
              className="select"
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="all">Category: All</option>
              {categories.map(c => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>

          <div style={{ width: '150px' }}>
            <select
              className="select"
              value={equipmentFilter}
              onChange={(e) => setEquipmentFilter(e.target.value)}
            >
              <option value="all">Equipment: All</option>
              {equipmentList.map(eq => <option key={eq} value={eq}>{eq}</option>)}
            </select>
          </div>

          <div style={{ width: '140px' }}>
            <select
              className="select"
              value={publishedFilter}
              onChange={(e) => setPublishedFilter(e.target.value)}
            >
              <option value="all">Status: All</option>
              <option value="1">Published</option>
              <option value="0">Unpublished</option>
            </select>
          </div>

          <button type="submit" className="btn btn-primary btn-sm">Filter</button>

          <button
            type="button"
            className="btn btn-secondary btn-sm"
            onClick={handleScanDuplicates}
            title="Scan for duplicate or conflicting exercise names"
          >
            🔍 Scan Duplicates
          </button>

          <button
            type="button"
            className="btn btn-primary btn-sm"
            onClick={() => {
              setFormData(initialForm);
              setShowAddModal(true);
            }}
          >
            + Add Exercise
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

      {/* Exercises Table */}
      <div className="card-table-wrapper">
        <div className="table-header-toolbar">
          <div className="table-title">
            Universal Exercise Library ({pagination.totalCount.toLocaleString()} movements)
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
            Showing page {pagination.page} of {pagination.totalPages}
          </div>
        </div>

        <table className="data-table">
          <thead>
            <tr>
              <th>Movement Name</th>
              <th>Muscle Group</th>
              <th>Equipment</th>
              <th>Difficulty</th>
              <th>Sets / Reps</th>
              <th>Status</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan="7" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  Loading exercises from database...
                </td>
              </tr>
            ) : exercises.length === 0 ? (
              <tr>
                <td colSpan="7" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                  No exercises matched your filters.
                </td>
              </tr>
            ) : (
              exercises.map((ex) => (
                <tr key={ex.id}>
                  <td>
                    <div style={{ fontWeight: '600' }}>{ex.name}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>ID: {ex.id}</div>
                  </td>
                  <td>
                    <span className="badge badge-accent">{ex.category}</span>
                  </td>
                  <td>
                    <span style={{ fontSize: '12.5px', color: 'var(--text-secondary)' }}>{ex.equipment}</span>
                  </td>
                  <td>
                    <span style={{ fontSize: '12.5px' }}>{ex.difficulty}</span>
                  </td>
                  <td style={{ fontFamily: 'var(--font-mono)', fontSize: '12.5px' }}>
                    {ex.suggested_sets} × {ex.suggested_reps}
                  </td>
                  <td>
                    <button
                      className={`badge ${ex.isPublished ? 'badge-success' : 'badge-warning'}`}
                      style={{ cursor: 'pointer', border: 'none' }}
                      onClick={() => handleTogglePublish(ex)}
                      title="Click to toggle publish status"
                    >
                      {ex.isPublished ? 'Published' : 'Draft / Hidden'}
                    </button>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: '6px' }}>
                      <button
                        className="btn btn-secondary btn-sm"
                        onClick={() => openEditModal(ex)}
                      >
                        Edit
                      </button>
                      <button
                        className="btn btn-danger btn-sm"
                        onClick={() => setDeleteModalEx(ex)}
                      >
                        🗑️
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>

        {/* Pagination */}
        <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button
            className="btn btn-secondary btn-sm"
            disabled={pagination.page <= 1}
            onClick={() => fetchExercises(pagination.page - 1)}
          >
            ← Previous
          </button>
          <span style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
            Page {pagination.page} of {pagination.totalPages || 1}
          </span>
          <button
            className="btn btn-secondary btn-sm"
            disabled={pagination.page >= pagination.totalPages}
            onClick={() => fetchExercises(pagination.page + 1)}
          >
            Next →
          </button>
        </div>
      </div>

      {/* Modal: Add or Edit Exercise */}
      {(showAddModal || editModalEx) && (
        <div className="modal-backdrop" onClick={() => { setShowAddModal(false); setEditModalEx(null); }}>
          <div className="modal-dialog" style={{ maxWidth: '680px' }} onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editModalEx ? `Edit: ${editModalEx.name}` : 'Add New Exercise to Universal Catalogue'}</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => { setShowAddModal(false); setEditModalEx(null); }}>✕</button>
            </div>
            <form onSubmit={editModalEx ? handleUpdateExercise : handleCreateExercise}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Exercise Name</label>
                  <input
                    type="text"
                    className="input"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    required
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Category</label>
                    <select
                      className="select"
                      value={formData.category}
                      onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    >
                      {categories.map(c => <option key={c} value={c}>{c}</option>)}
                    </select>
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Equipment Required</label>
                    <select
                      className="select"
                      value={formData.equipment}
                      onChange={(e) => setFormData({ ...formData, equipment: e.target.value })}
                    >
                      {equipmentList.map(eq => <option key={eq} value={eq}>{eq}</option>)}
                    </select>
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Primary Target Muscle</label>
                    <input
                      type="text"
                      className="input"
                      value={formData.primaryMuscle}
                      onChange={(e) => setFormData({ ...formData, primaryMuscle: e.target.value })}
                      required
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Secondary Muscles (comma separated)</label>
                    <input
                      type="text"
                      className="input"
                      value={formData.secondaryMuscles}
                      onChange={(e) => setFormData({ ...formData, secondaryMuscles: e.target.value })}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Difficulty</label>
                    <select
                      className="select"
                      value={formData.difficulty}
                      onChange={(e) => setFormData({ ...formData, difficulty: e.target.value })}
                    >
                      <option value="Beginner">Beginner</option>
                      <option value="Intermediate">Intermediate</option>
                      <option value="Advanced">Advanced</option>
                    </select>
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Suggested Sets</label>
                    <input
                      type="number"
                      className="input"
                      value={formData.suggestedSets}
                      onChange={(e) => setFormData({ ...formData, suggestedSets: e.target.value })}
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Suggested Reps</label>
                    <input
                      type="text"
                      className="input"
                      value={formData.suggestedReps}
                      onChange={(e) => setFormData({ ...formData, suggestedReps: e.target.value })}
                    />
                  </div>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Step-by-Step Instructions (one per line)</label>
                  <textarea
                    className="textarea"
                    rows="4"
                    value={formData.instructions}
                    onChange={(e) => setFormData({ ...formData, instructions: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Movement Description & Purpose</label>
                  <textarea
                    className="textarea"
                    rows="2"
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '4px' }}>Media / Animation URL</label>
                  <input
                    type="text"
                    className="input"
                    placeholder="assets/catalogue/... or https://..."
                    value={formData.mediaUrl}
                    onChange={(e) => setFormData({ ...formData, mediaUrl: e.target.value })}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => { setShowAddModal(false); setEditModalEx(null); }}>Cancel</button>
                <button type="submit" className="btn btn-primary">{editModalEx ? 'Save Changes' : 'Create Exercise'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Duplicates Detector Results */}
      {duplicatesData && (
        <div className="modal-backdrop" onClick={() => setDuplicatesData(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Exercise Duplicate Detection Scan</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setDuplicatesData(null)}>✕</button>
            </div>
            <div className="modal-body">
              {duplicatesData.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '24px' }}>
                  <div style={{ fontSize: '32px', marginBottom: '12px' }}>✅</div>
                  <h4 style={{ fontWeight: '700' }}>Zero Collisions Detected</h4>
                  <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '6px' }}>
                    All 5,600+ exercises in the database maintain unique normalized names and IDs.
                  </p>
                </div>
              ) : (
                <div>
                  <p style={{ marginBottom: '12px' }}>The following duplicates were discovered:</p>
                  {duplicatesData.map(d => (
                    <div key={d.clean_name} style={{ padding: '8px 12px', backgroundColor: 'var(--bg-muted)', borderRadius: '6px', marginBottom: '8px' }}>
                      <strong>{d.clean_name}</strong>: {d.count} occurrences
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button className="btn btn-primary" onClick={() => setDuplicatesData(null)}>Close</button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Delete Exercise Confirmation */}
      {deleteModalEx && (
        <div className="modal-backdrop" onClick={() => setDeleteModalEx(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Remove Exercise</h3>
              <button className="btn btn-secondary btn-sm" onClick={() => setDeleteModalEx(null)}>✕</button>
            </div>
            <div className="modal-body">
              <p>Are you sure you want to remove <strong>{deleteModalEx.name}</strong> from the catalogue?</p>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setDeleteModalEx(null)}>Cancel</button>
              <button className="btn btn-danger" onClick={handleDeleteExercise}>Confirm Remove</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

