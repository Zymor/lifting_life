import { useState } from 'react'
import { useStore } from '../store/useStore.js'
import { t } from '../lib/i18n.js'
import Icon from '../components/Icon.jsx'

export default function Community() {
  const { S, update } = useStore()
  const community = S.community || {}

  // Tab State: 'feed' | 'friends' | 'circles'
  const [activeTab, setActiveTab] = useState('feed')

  // Search User
  const [searchUser, setSearchUser] = useState('')
  const [newCircleName, setNewCircleName] = useState('')
  const [newCircleDesc, setNewCircleDesc] = useState('')
  const [showCircleModal, setShowCircleModal] = useState(false)

  // Posts in Feed
  const feed = community.activityFeed || [
    { id: 'a1', username: 'alex_lifts', displayName: 'Alex Rivera', time: '2h ago', text: 'Hit a clean single on Competition Squat: 140kg @ RPE 9.0! Program progression on track.', likes: 14, comments: 4, lift: 'Squat', weight: 140 },
    { id: 'a2', username: 'sarah_strong', displayName: 'Sarah Chen', time: '4h ago', text: 'Completed Upper Body Volume day from the Powerbuilding split. 4x8 Incline DB Bench felt effortless.', likes: 9, comments: 2, program: 'Powerbuilding 4-Day' },
    { id: 'a3', username: 'marcus_iron', displayName: 'Marcus Vance', time: '1d ago', text: 'Speed Deadlifts 8x2 @ 180kg. Working on bar velocity and hip lockout.', likes: 21, comments: 7, lift: 'Deadlift', weight: 180 },
  ]

  // Friends & Requests
  const friends = community.friends || [
    { id: 'u1', username: 'alex_lifts', displayName: 'Alex Rivera', avatar: '', status: 'friend', bio: 'Powerlifter (IPF 83kg) | Road to 550kg total', recentWorkout: 'Squat 140kg x 1' },
    { id: 'u2', username: 'sarah_strong', displayName: 'Sarah Chen', avatar: '', status: 'friend', bio: 'Powerbuilding & hypertrophy enthusiast', recentWorkout: 'Bench 75kg x 6' },
    { id: 'u3', username: 'marcus_iron', displayName: 'Marcus Vance', avatar: '', status: 'pending_incoming', bio: 'Deadlift specialist | 240kg puller', recentWorkout: 'Deadlift 220kg x 2' },
  ]

  // Training Circles
  const circles = community.circles || [
    { id: 'c1', name: 'Powerlifting Heavy Hitters', description: 'Weekly SBD tracking, video form checks & mock meets', memberCount: 14, isOwner: true, targetGoal: '500kg+ Total' },
    { id: 'c2', name: 'Early Bird Lifters', description: 'Accountability group for 6 AM training sessions', memberCount: 28, isOwner: false, targetGoal: 'Consistency 4x/week' },
  ]

  // Friend Request actions
  const handleAcceptFriend = (friendId) => {
    update(state => {
      if (!state.community) state.community = {}
      const f = (state.community.friends || []).find(x => x.id === friendId)
      if (f) f.status = 'friend'
    })
  }

  const handleRemoveFriend = (friendId) => {
    update(state => {
      if (!state.community) state.community = {}
      state.community.friends = (state.community.friends || []).filter(x => x.id !== friendId)
    })
  }

  // Like a post
  const handleLikePost = (postId) => {
    update(state => {
      if (!state.community) state.community = {}
      const post = (state.community.activityFeed || []).find(p => p.id === postId)
      if (post) post.likes = (post.likes || 0) + 1
    })
  }

  // Create Circle
  const handleCreateCircle = (e) => {
    e.preventDefault()
    if (!newCircleName.trim()) return
    const newCircle = {
      id: 'circle_' + Date.now(),
      name: newCircleName,
      description: newCircleDesc,
      memberCount: 1,
      isOwner: true,
      targetGoal: 'Team Strength & Consistency'
    }

    update(state => {
      if (!state.community) state.community = {}
      if (!state.community.circles) state.community.circles = []
      state.community.circles.unshift(newCircle)
    })

    setShowCircleModal(false)
    setNewCircleName('')
    setNewCircleDesc('')
  }

  return (
    <div className="view community-view">
      {/* Header */}
      <header className="page-header">
        <div className="page-title-wrap">
          <h1 className="page-title">{t('Community, Friends & Training Circles')}</h1>
          <p className="page-subtitle">Connect with athletes, share workouts, and build private accountability squads</p>
        </div>
        <button
          className="primary-action-btn"
          onClick={() => setShowCircleModal(true)}
        >
          <Icon name="plus" size={16} />
          <span>{t('New Circle')}</span>
        </button>
      </header>

      {/* Tabs */}
      <div className="subnav-tabs">
        <button className={`subnav-tab ${activeTab === 'feed' ? 'active' : ''}`} onClick={() => setActiveTab('feed')}>
          <Icon name="chat" size={18} />
          <span>Activity Feed</span>
        </button>
        <button className={`subnav-tab ${activeTab === 'friends' ? 'active' : ''}`} onClick={() => setActiveTab('friends')}>
          <Icon name="person" size={18} />
          <span>Friends & Requests ({friends.filter(f => f.status === 'pending_incoming').length ? '1 pending' : friends.length})</span>
        </button>
        <button className={`subnav-tab ${activeTab === 'circles' ? 'active' : ''}`} onClick={() => setActiveTab('circles')}>
          <Icon name="personCircle" size={18} />
          <span>Training Circles ({circles.length})</span>
        </button>
      </div>

      {/* 1. Activity Feed */}
      {activeTab === 'feed' && (
        <div className="feed-container">
          <div className="feed-list">
            {feed.map(post => (
              <div key={post.id} className="feed-post-card card">
                <div className="post-header">
                  <div className="post-avatar">
                    <Icon name="person" size={20} />
                  </div>
                  <div className="post-author-info">
                    <span className="post-author-name">{post.displayName}</span>
                    <span className="post-author-meta">@{post.username} • {post.time}</span>
                  </div>
                  {post.lift && <span className="post-lift-badge">{post.lift} PR</span>}
                </div>

                <p className="post-body-text">{post.text}</p>

                <div className="post-footer">
                  <button className="post-action-btn" onClick={() => handleLikePost(post.id)}>
                    <Icon name="heart" size={16} />
                    <span>{post.likes} Cheers</span>
                  </button>
                  <button className="post-action-btn">
                    <Icon name="chat" size={16} />
                    <span>{post.comments} Comments</span>
                  </button>
                  <button className="post-action-btn">
                    <Icon name="share" size={16} />
                    <span>Share</span>
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 2. Friends & Requests */}
      {activeTab === 'friends' && (
        <div className="friends-container">
          {/* User Search Bar */}
          <div className="user-search-card card">
            <div className="search-input-box">
              <Icon name="magnifier" size={18} />
              <input
                type="text"
                placeholder="Find lifters by @username or name..."
                value={searchUser}
                onChange={e => setSearchUser(e.target.value)}
              />
            </div>
          </div>

          {/* Pending Requests */}
          {friends.filter(f => f.status === 'pending_incoming').length > 0 && (
            <div className="friend-section">
              <h3 className="section-title">Pending Friend Requests</h3>
              <div className="friend-cards-list">
                {friends.filter(f => f.status === 'pending_incoming').map(f => (
                  <div key={f.id} className="friend-card card pending">
                    <div className="friend-info">
                      <div className="post-avatar"><Icon name="person" size={20} /></div>
                      <div>
                        <div className="friend-name">{f.displayName}</div>
                        <div className="friend-sub">@{f.username} • {f.bio}</div>
                      </div>
                    </div>
                    <div className="friend-req-actions">
                      <button className="btn-confirm-sm" onClick={() => handleAcceptFriend(f.id)}>Accept</button>
                      <button className="btn-cancel-sm" onClick={() => handleRemoveFriend(f.id)}>Decline</button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Connected Friends List */}
          <div className="friend-section">
            <h3 className="section-title">Connected Friends</h3>
            <div className="friend-cards-list">
              {friends.filter(f => f.status === 'friend').map(f => (
                <div key={f.id} className="friend-card card">
                  <div className="friend-info">
                    <div className="post-avatar"><Icon name="person" size={20} /></div>
                    <div>
                      <div className="friend-name">{f.displayName}</div>
                      <div className="friend-sub">@{f.username} • {f.bio}</div>
                      <div className="recent-activity">Recent: {f.recentWorkout}</div>
                    </div>
                  </div>
                  <div className="friend-card-actions">
                    <button className="iconbtn" title="Remove Friend" onClick={() => handleRemoveFriend(f.id)}>
                      <Icon name="trash" size={16} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* 3. Training Circles */}
      {activeTab === 'circles' && (
        <div className="circles-container">
          <div className="circles-intro card">
            <div className="circle-intro-text">
              <h3>Training Circles</h3>
              <p>Private accountability squads for shared schedules, group PR tracking, and mutual motivation.</p>
            </div>
            <button className="primary-action-btn" onClick={() => setShowCircleModal(true)}>
              <Icon name="plus" size={16} />
              <span>Create Circle</span>
            </button>
          </div>

          <div className="circles-grid">
            {circles.map(c => (
              <div key={c.id} className="circle-card card">
                <div className="circle-header">
                  <h4>{c.name}</h4>
                  {c.isOwner && <span className="owner-badge">Owner</span>}
                </div>
                <p className="circle-desc">{c.description}</p>
                <div className="circle-meta">
                  <span className="circle-members"><Icon name="person" size={14} /> {c.memberCount} Members</span>
                  <span className="circle-goal"><Icon name="target" size={14} /> {c.targetGoal}</span>
                </div>
                <div className="circle-actions">
                  <button className="btn-enter-circle">Enter Circle Feed</button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* New Circle Modal */}
      {showCircleModal && (
        <div className="search-overlay" onClick={() => setShowCircleModal(false)}>
          <div className="search-modal" onClick={e => e.stopPropagation()}>
            <div className="search-header">
              <span className="modal-title-text">Create Training Circle</span>
              <button className="search-close-btn" onClick={() => setShowCircleModal(false)}>✕</button>
            </div>

            <form onSubmit={handleCreateCircle} className="log-modal-form">
              <div className="form-group">
                <label>Circle Name</label>
                <input
                  type="text"
                  placeholder="e.g. 500kg Total Club / 6AM Crew"
                  value={newCircleName}
                  onChange={e => setNewCircleName(e.target.value)}
                  required
                />
              </div>

              <div className="form-group">
                <label>Squad Purpose & Description</label>
                <textarea
                  placeholder="Weekly targets, shared program, check-ins..."
                  value={newCircleDesc}
                  onChange={e => setNewCircleDesc(e.target.value)}
                  rows="3"
                />
              </div>

              <div className="modal-actions-bar">
                <button type="button" className="btn-cancel" onClick={() => setShowCircleModal(false)}>Cancel</button>
                <button type="submit" className="btn-confirm">Launch Circle</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

