import { useLocation, useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { effectiveRoutineIds, effectiveRoutines } from '../lib/history.js'
import { todayISO } from '../lib/format.js'
import { t } from '../lib/i18n.js'
import Icon from './Icon.jsx'
import Elapsed from './Elapsed.jsx'

export default function Sidebar({ onStart, onOpenSearch }) {
  const nav = useNavigate()
  const loc = useLocation()
  const S = useStore(s => s.S)
  const user = useStore(s => s.user)
  const isGuest = useStore(s => s.isGuest())

  if (!user && !isGuest) return null

  const cur = loc.pathname.split('/')[1] || 'home'
  const isWorkout = cur === 'workout'
  const running = !!S.active && !isWorkout && !S.active.editingWorkoutId && !S.active.backfill && S.active.start > 0

  const navItems = [
    { key: 'home', label: t('Dashboard'), path: '/home', icon: 'house' },
    { key: 'library', label: t('Exercise Library'), path: '/library', icon: 'dumbbell' },
    { key: 'schedule', label: t('Workout Schedule'), path: '/schedule', icon: 'calendar' },
    { key: 'powerlifting', label: t('Powerlifting'), path: '/powerlifting', icon: 'barbell', badge: 'Big 3' },
    { key: 'programs', label: t('Training Programs'), path: '/programs', icon: 'clipboard' },
    { key: 'community', label: t('Friends'), path: '/community', icon: 'personCircle' },
    { key: 'analytics', label: t('Progress Analytics'), path: '/analytics', icon: 'chart' },
    { key: 'profile', label: t('My Profile'), path: '/profile', icon: 'person' },
    { key: 'settings', label: t('Settings'), path: '/settings', icon: 'gear' },
  ]

  const isActive = (item) => {
    if (cur === item.key) return true
    if (item.key === 'schedule' && cur === 'plan') return true
    if (item.key === 'analytics' && (cur === 'stats' || cur === 'history')) return true
    if (item.key === 'programs' && cur === 'plan') return true
    return false
  }

  const startWorkout = () => {
    if (!S.active) {
      if (effectiveRoutines(S, todayISO()).some(r => r.ex.length)) {
        onStart(effectiveRoutineIds(S, todayISO()))
        return
      }
    }
    nav('/workout')
  }

  const athleteName = S.athleteProfile?.displayName || user?.name || 'Lifting Athlete'
  const athleteUser = S.athleteProfile?.username || (user?.email ? user.email.split('@')[0] : 'lifter')

  return (
    <aside id="desktop-sidebar">
      {/* Brand Header */}
      <div className="sidebar-brand" onClick={() => nav('/home')}>
        <div className="brand-logo">
          <img src="lifting-life-mark-v2-180.png" alt="" width="48" height="48" style={{ display: 'block', borderRadius: 'inherit' }} />
        </div>
        <div className="brand-info">
          <span className="brand-title">Lifting Life</span>
          <span className="brand-badge">2.0</span>
        </div>
      </div>

      {/* Universal Search trigger */}
      <div className="sidebar-search-box">
        <button className="sidebar-search-btn" onClick={onOpenSearch}>
          <Icon name="magnifier" size={16} />
          <span>{t('Search...')}</span>
          <kbd className="cmd-k">Ctrl K</kbd>
        </button>
      </div>

      {/* Quick Start Workout Action */}
      <div className="sidebar-action-wrap">
        <button
          className={'sidebar-start-btn' + (S.active ? ' active-session' : '')}
          onClick={startWorkout}
        >
          <span className="action-icon">
            <Icon name={S.active ? 'play' : 'plus'} size={18} />
          </span>
          <div className="action-text">
            <span className="action-title">
              {running ? (
                <>Resume (<Elapsed start={S.active.start} />)</>
              ) : S.active ? (
                isWorkout ? t('Active Workout') : t('Resume Workout')
              ) : (
                t('Start Workout')
              )}
            </span>
            <span className="action-sub">
              {S.active ? 'Session in progress' : 'Log sets & exercises'}
            </span>
          </div>
        </button>
      </div>

      {/* Navigation List */}
      <nav className="sidebar-nav">
        <div className="sidebar-nav-section-title">MAIN NAVIGATION</div>
        {navItems.map(item => {
          const active = isActive(item)
          return (
            <button
              key={item.key}
              className={`sidebar-nav-item ${active ? 'active' : ''}`}
              onClick={() => nav(item.path)}
            >
              <span className="nav-item-icon">
                <Icon name={item.icon} size={20} />
              </span>
              <span className="nav-item-label">{item.label}</span>
              {item.badge && <span className="nav-item-badge">{item.badge}</span>}
            </button>
          )
        })}
      </nav>

      {/* Athlete Footer Profile */}
      <div className="sidebar-footer" onClick={() => nav('/profile')}>
        <div className="athlete-avatar">
          <Icon name="person" size={20} />
        </div>
        <div className="athlete-info">
          <span className="athlete-name">{athleteName}</span>
          <span className="athlete-handle">@{athleteUser}</span>
        </div>
        <div className="athlete-status-dot" title="Ready to train" />
      </div>
    </aside>
  )
}

