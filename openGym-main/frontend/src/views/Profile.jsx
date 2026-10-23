import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { t } from '../lib/i18n.js'
import Icon from '../components/Icon.jsx'

export default function Profile() {
  const navigate = useNavigate()
  const { S, update, user } = useStore()
  const athlete = S.athleteProfile || {}
  const prs = S.powerlifting?.prs || {}
  const unit = S.unit || 'kg'

  const [isEditing, setIsEditing] = useState(false)
  const [displayName, setDisplayName] = useState(athlete.displayName || 'Lifting Life Athlete')
  const [username, setUsername] = useState(athlete.username || 'lifter_one')
  const [bio, setBio] = useState(athlete.bio || 'Dedicated to strength, powerlifting, and lifelong fitness.')
  const [level, setLevel] = useState(athlete.experienceLevel || 'Intermediate')
  const [weightClass, setWeightClass] = useState(athlete.weightClass || '83kg')
  const [primaryGoal, setPrimaryGoal] = useState(athlete.primaryGoal || 'Powerlifting & Strength')
  const [privacy, setPrivacy] = useState(S.community?.profilePrivacy || 'public')

  const totalSBD = (prs.squat?.weight || 0) + (prs.bench?.weight || 0) + (prs.deadlift?.weight || 0)

  const handleSaveProfile = (e) => {
    e.preventDefault()
    update(state => {
      if (!state.athleteProfile) state.athleteProfile = {}
      state.athleteProfile.displayName = displayName
      state.athleteProfile.username = username
      state.athleteProfile.bio = bio
      state.athleteProfile.experienceLevel = level
      state.athleteProfile.weightClass = weightClass
      state.athleteProfile.primaryGoal = primaryGoal

      if (!state.community) state.community = {}
      state.community.profilePrivacy = privacy
    })
    setIsEditing(false)
  }

  return (
    <div className="view profile-view">
      {/* Header */}
      <header className="page-header">
        <div className="page-title-wrap">
          <h1 className="page-title">{t('My Athlete Profile')}</h1>
          <p className="page-subtitle">Personal lifting stats, achievements, and community visibility</p>
        </div>
        <button
          className="primary-action-btn secondary"
          onClick={() => setIsEditing(!isEditing)}
        >
          <Icon name={isEditing ? 'xmark' : 'pencil'} size={16} />
          <span>{isEditing ? 'Cancel' : 'Edit Profile'}</span>
        </button>
      </header>

      {/* Main Profile Card */}
      <div className="athlete-hero-card card">
        <div className="hero-top">
          <div className="hero-avatar">
            <Icon name="person" size={36} />
          </div>
          <div className="hero-details">
            <h2>{displayName}</h2>
            <span className="hero-handle">@{username} • {user?.email || 'Local Athlete'}</span>
            <div className="hero-tags">
              <span className="htag">{level}</span>
              <span className="htag">{weightClass}</span>
              <span className="htag">{primaryGoal}</span>
              <span className={`htag privacy-${privacy}`}>{privacy.toUpperCase()}</span>
            </div>
          </div>
        </div>

        <p className="hero-bio">{bio}</p>

        {/* Big 3 Showcase */}
        <div className="sbd-badges-row">
          <div className="sbd-badge">
            <span className="lbl">Squat</span>
            <span className="val">{prs.squat?.weight > 0 ? `${prs.squat.weight} ${unit}` : `—`}</span>
          </div>
          <div className="sbd-badge">
            <span className="lbl">Bench Press</span>
            <span className="val">{prs.bench?.weight > 0 ? `${prs.bench.weight} ${unit}` : `—`}</span>
          </div>
          <div className="sbd-badge">
            <span className="lbl">Deadlift</span>
            <span className="val">{prs.deadlift?.weight > 0 ? `${prs.deadlift.weight} ${unit}` : `—`}</span>
          </div>
          <div className="sbd-badge highlight">
            <span className="lbl">Total</span>
            <span className="val">{totalSBD || 420} {unit}</span>
          </div>
        </div>
      </div>

      {/* Edit Form */}
      {isEditing && (
        <div className="edit-profile-card card">
          <h3>Edit Profile Information</h3>
          <form onSubmit={handleSaveProfile} className="profile-form">
            <div className="form-row">
              <div className="form-group">
                <label>Display Name</label>
                <input
                  type="text"
                  value={displayName}
                  onChange={e => setDisplayName(e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label>Username</label>
                <input
                  type="text"
                  value={username}
                  onChange={e => setUsername(e.target.value)}
                  required
                />
              </div>
            </div>

            <div className="form-group">
              <label>Bio & Training Philosophy</label>
              <textarea
                value={bio}
                onChange={e => setBio(e.target.value)}
                rows="3"
              />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Experience Level</label>
                <select value={level} onChange={e => setLevel(e.target.value)}>
                  <option value="Beginner">Beginner</option>
                  <option value="Intermediate">Intermediate</option>
                  <option value="Advanced">Advanced</option>
                  <option value="Elite">Elite</option>
                </select>
              </div>

              <div className="form-group">
                <label>Weight Class</label>
                <input
                  type="text"
                  value={weightClass}
                  onChange={e => setWeightClass(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Profile Privacy</label>
                <select value={privacy} onChange={e => setPrivacy(e.target.value)}>
                  <option value="public">Public (Visible in search)</option>
                  <option value="friends">Friends Only</option>
                  <option value="private">Private</option>
                </select>
              </div>
            </div>

            <div className="modal-actions-bar">
              <button type="button" className="btn-cancel" onClick={() => setIsEditing(false)}>Cancel</button>
              <button type="submit" className="btn-confirm">Save Changes</button>
            </div>
          </form>
        </div>
      )}

      {/* Profile Sections Grid */}
      <div className="profile-grid">
        <div className="profile-card card" onClick={() => navigate('/powerlifting')}>
          <div className="pcard-icon"><Icon name="barbell" size={24} /></div>
          <h4>Powerlifting Command Center</h4>
          <p>Access your Big 3 lift cards, 1RM percentages, and plate calculator.</p>
        </div>

        <div className="profile-card card" onClick={() => navigate('/community')}>
          <div className="pcard-icon"><Icon name="personCircle" size={24} /></div>
          <h4>Training Circles & Friends</h4>
          <p>Manage friend requests, connections, and squad memberships.</p>
        </div>

        <div className="profile-card card" onClick={() => navigate('/analytics')}>
          <div className="pcard-icon"><Icon name="chart" size={24} /></div>
          <h4>Volume & Analytics</h4>
          <p>Explore calculated work volume and progression graphs.</p>
        </div>

        <div className="profile-card card" onClick={() => navigate('/settings')}>
          <div className="pcard-icon"><Icon name="gear" size={24} /></div>
          <h4>Account & Security Settings</h4>
          <p>Manage themes, weight units, passkeys, and data backups.</p>
        </div>
      </div>
    </div>
  )
}

