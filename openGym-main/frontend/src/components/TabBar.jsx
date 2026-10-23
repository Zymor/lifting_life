import { useLocation, useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { effectiveRoutineIds, effectiveRoutines } from '../lib/history.js'
import { todayISO } from '../lib/format.js'
import { t } from '../lib/i18n.js'
import Icon from './Icon.jsx'
import Elapsed from './Elapsed.jsx'
import { useConnectionTrouble } from './SyncBanner.jsx'

function Tab({ active, icon, label, onClick, dot }) {
  return (
    <button className={active ? 'on' : ''} onClick={onClick} aria-label={dot ? label + ', ' + t('Connection problem') : undefined}>
      <span className="tab-ic"><Icon name={icon} />{dot && <span className="tab-dot" aria-hidden="true" />}</span>
      <span>{label}</span>
    </button>
  )
}

export default function TabBar({ onStart }) {
  const nav = useNavigate()
  const loc = useLocation()
  const S = useStore(s => s.S)
  const user = useStore(s => s.user)
  const isGuest = useStore(s => s.isGuest())
  const trouble = useConnectionTrouble()

  if (!user && !isGuest) return null
  const cur = loc.pathname.split('/')[1] || 'home'

  const on = k => {
    if (cur === k) return true
    if (k === 'home' && (cur === 'dashboard' || cur === 'profile' || cur === 'settings')) return true
    if (k === 'plan' && (cur === 'schedule' || cur === 'programs')) return true
    if (k === 'stats' && (cur === 'analytics' || cur === 'powerlifting' || cur === 'history' || cur === 'structural-balance')) return true
    if (k === 'library' && cur === 'muscles') return true
    return false
  }

  const running = !!S.active && cur !== 'workout' && !S.active.editingWorkoutId && !S.active.backfill && S.active.start > 0
  const startWorkout = () => {
    if (!S.active) {
      if (effectiveRoutines(S, todayISO()).some(r => r.ex.length)) {
        onStart(effectiveRoutineIds(S, todayISO()))
        return
      }
    }
    nav('/workout')
  }

  return (
    <nav id="tabbar">
      <Tab active={on('home')} icon="house" label={t('Home')} dot={trouble} onClick={() => nav('/home')} />
      <Tab active={on('plan')} icon="calendar" label={t('Plan')} onClick={() => nav('/schedule')} />
      <button
        className={'start' + (S.active ? ' rec' : '') + (S.active && cur === 'workout' ? ' on' : '')}
        onClick={startWorkout}
        aria-label={running ? t('Resume') : undefined}
      >
        <span className="cir"><Icon name="play" /></span>
        {running ? (
          <span className="tab-time"><Elapsed start={S.active.start} /></span>
        ) : (
          <span>
            {S.active
              ? cur === 'workout'
                ? t('Workout')
                : S.active.editingWorkoutId
                ? t('Edit workout')
                : t('Resume')
              : t('Start')}
          </span>
        )}
      </button>
      <Tab active={on('stats')} icon="chart" label={t('Stats')} onClick={() => nav('/analytics')} />
      <Tab active={on('library')} icon="dumbbell" label={t('Exercises')} onClick={() => nav('/library')} />
    </nav>
  )
}
