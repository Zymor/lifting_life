import React, { useState } from 'react';
import { adminApi } from '../api';

export default function ContentTab() {
  const [notification, setNotification] = useState({
    title: '',
    body: '',
    targetGroup: 'all',
    type: 'broadcast'
  });
  const [sending, setSending] = useState(false);
  const [statusMsg, setStatusMsg] = useState('');

  const [articles, setArticles] = useState([
    {
      id: 1,
      title: 'Optimal Hypertrophy: Progressive Overload & RPE Guidelines',
      category: 'Education',
      author: 'Lifting Life Editorial',
      status: 'published',
      publishedAt: '2026-10-15'
    },
    {
      id: 2,
      title: 'Nutrition Timing: Protein Synthesis Windows & Hydration',
      category: 'Nutrition',
      author: 'Lifting Life Science Team',
      status: 'published',
      publishedAt: '2026-10-18'
    },
    {
      id: 3,
      title: 'Beginner Guide: Compound Lifts vs Isolation Movements',
      category: 'Guides',
      author: 'Head Coach',
      status: 'draft',
      publishedAt: '—'
    }
  ]);

  const handleSendNotification = (e) => {
    e.preventDefault();
    if (!notification.title || !notification.body) return;
    setSending(true);
    setTimeout(() => {
      setSending(false);
      setStatusMsg(`Broadcast successfully dispatched to target segment "${notification.targetGroup}".`);
      setNotification({ title: '', body: '', targetGroup: 'all', type: 'broadcast' });
      setTimeout(() => setStatusMsg(''), 4000);
    }, 600);
  };

  return (
    <div className="tab-pane">
      <div className="tab-header">
        <div>
          <h2>Content Management & Athlete Communications</h2>
          <p className="tab-subtitle">Manage guides, educational content, in-app notifications, and broadcast messages.</p>
        </div>
      </div>

      {statusMsg && <div className="alert success">{statusMsg}</div>}

      <div className="grid-2col" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(350px, 1fr))', gap: '1.5rem', marginBottom: '1.5rem' }}>
        <div className="card">
          <h3 style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>📢 Send Athlete Push Broadcast</h3>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: '1rem' }}>
            Dispatch instant notifications to active athletes on mobile and web clients.
          </p>
          <form onSubmit={handleSendNotification} style={{ display: 'flex', flexDirection: 'column', gap: '0.8rem' }}>
            <div>
              <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: '0.3rem' }}>Broadcast Title</label>
              <input
                type="text"
                value={notification.title}
                onChange={(e) => setNotification({ ...notification, title: e.target.value })}
                placeholder="e.g. New 12-Week Hypertrophy Program Live!"
                required
                style={{ width: '100%', padding: '0.65rem 0.8rem', borderRadius: '6px', border: '1px solid var(--border)', background: 'var(--bg-input)', color: 'var(--text)' }}
              />
            </div>
            <div>
              <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: '0.3rem' }}>Message Payload</label>
              <textarea
                value={notification.body}
                onChange={(e) => setNotification({ ...notification, body: e.target.value })}
                rows="3"
                placeholder="Check out the newly added scientifically optimized PPL routine..."
                required
                style={{ width: '100%', padding: '0.65rem 0.8rem', borderRadius: '6px', border: '1px solid var(--border)', background: 'var(--bg-input)', color: 'var(--text)', resize: 'vertical' }}
              />
            </div>
            <div style={{ display: 'flex', gap: '1rem' }}>
              <div style={{ flex: 1 }}>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: '0.3rem' }}>Audience Segment</label>
                <select
                  value={notification.targetGroup}
                  onChange={(e) => setNotification({ ...notification, targetGroup: e.target.value })}
                  style={{ width: '100%', padding: '0.65rem 0.8rem', borderRadius: '6px', border: '1px solid var(--border)', background: 'var(--bg-input)', color: 'var(--text)' }}
                >
                  <option value="all">All Active Athletes (100%)</option>
                  <option value="active_7d">Active Past 7 Days</option>
                  <option value="inactive_14d">Inactive Athletes (Re-engagement)</option>
                  <option value="premium">Premium Subscribers</option>
                </select>
              </div>
            </div>
            <button type="submit" className="btn btn-primary" style={{ marginTop: '0.5rem' }} disabled={sending}>
              {sending ? 'Dispatching...' : 'Dispatch Broadcast'}
            </button>
          </form>
        </div>

        <div className="card">
          <h3 style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>📋 Publishing Quick Actions</h3>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: '1.2rem' }}>
            Global content governance and community guidelines status.
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.9rem' }}>
            <div style={{ padding: '0.8rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--bg-input)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <strong style={{ fontSize: '0.9rem' }}>Community Moderation Filter</strong>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Automated profanity and spam filter for public workout notes.</p>
              </div>
              <span className="badge badge-success">Active</span>
            </div>
            <div style={{ padding: '0.8rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--bg-input)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <strong style={{ fontSize: '0.9rem' }}>Asset CDN Caching</strong>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Universal exercise GIFs and video demonstrations cached edge-wide.</p>
              </div>
              <span className="badge badge-success">Optimized</span>
            </div>
            <div style={{ padding: '0.8rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--bg-input)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <strong style={{ fontSize: '0.9rem' }}>In-App Onboarding Flow</strong>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>First-time user questionnaire, 1RM calculator, and goal selection.</p>
              </div>
              <span className="badge badge-info">Enabled</span>
            </div>
          </div>
        </div>
      </div>

      <div className="card">
        <h3 style={{ fontSize: '1.1rem', marginBottom: '1rem' }}>Educational Articles & Guides</h3>
        <div className="table-responsive">
          <table className="data-table">
            <thead>
              <tr>
                <th>Article Title</th>
                <th>Category</th>
                <th>Author</th>
                <th>Status</th>
                <th>Published Date</th>
              </tr>
            </thead>
            <tbody>
              {articles.map((art) => (
                <tr key={art.id}>
                  <td style={{ fontWeight: 600 }}>{art.title}</td>
                  <td><span className="badge badge-secondary">{art.category}</span></td>
                  <td style={{ color: 'var(--text-muted)' }}>{art.author}</td>
                  <td>
                    <span className={`badge ${art.status === 'published' ? 'badge-success' : 'badge-warning'}`}>
                      {art.status}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>{art.publishedAt}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

