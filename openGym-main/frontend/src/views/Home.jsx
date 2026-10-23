import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { effectiveRoutines, effectiveRoutineIds, nextTrainingDay, streakWeeks, lastBW } from '../lib/history.js'
import { fmtNum, fmtDate, todayISO, isoOf, weekStartOf, weekDayOffset, DAYS, DAYN } from '../lib/format.js'
import { t, tn, dateLocale } from '../lib/i18n.js'
import { bwSheet, goalSheet, dayOverrideSheet, calendarSheet, startFlow, starterPlanSheet, bwDeltaColor, weighInsSheet } from '../sheets.jsx'
import LineChart from '../components/LineChart.jsx'
import Icon from '../components/Icon.jsx'
import QueueRow from '../components/QueueRow.jsx'
import { queueOf, queueView, weekTally, pinState } from '../lib/queue.js'
import { scheduleModeOf } from '../lib/rotation.js'
import { useConnectionTrouble } from '../components/SyncBanner.jsx'
import { Button } from '../components/ui.jsx'
import { tappable } from '../lib/use-sheet-keyboard.js'
import { glyphOf } from '../lib/glyphs.js'
import { dayNoteOf } from '../lib/day-notes.js'

export default function Home() {
  const nav = useNavigate()
  const S = useStore(s => s.S)
  const user = useStore(s => s.user)
  const trouble = useConnectionTrouble()
  const [weekOffset, setWeekOffset] = useState(0)

  const today = new Date()
  const todayRoutines = effectiveRoutines(S, todayISO())
  const routine = todayRoutines[0] || null
  const todayName = todayRoutines.map(r => r.name).join(' + ')
  const todayOvr = S.dayPlan[todayISO()] !== undefined && pinState(S, S.dayPlan[todayISO()]) !== 'done'
  const editingSaved = !!S.active?.editingWorkoutId
  const bw = lastBW(S)
  const prevBW = S.bodyweight.length > 1 ? S.bodyweight[S.bodyweight.length - 2] : null
  const delta = bw && prevBW ? bw.w - prevBW.w : null

  const ws = weekStartOf(S)
  const wkStart = new Date(today)
  wkStart.setDate(today.getDate() - weekDayOffset(today.getDay(), ws) + weekOffset * 7)
  const doneDays = new Set(S.workouts.map(w => w.d))

  const loggedToday = S.workouts.filter(w => w.d === todayISO())
  const queueIds = queueOf(S)?.ids || []
  const coveredToday = id => !queueIds.includes(id) && loggedToday.some(w => (Array.isArray(w.routineIds) ? w.routineIds : [w.routineId]).includes(id))
  const doneToday = (todayRoutines.every(r => coveredToday(r.id)) && loggedToday.at(-1)) || null

  const strip = []
  for (let i = 0; i < 7; i++) {
    const d = new Date(wkStart); d.setDate(wkStart.getDate() + i)
    const iso = isoOf(d)
    const eff = effectiveRoutineIds(S, iso).length > 0, ovr = S.dayPlan[iso] !== undefined, done = doneDays.has(iso)
    const dot = done ? ' done' : dayNoteOf(S, iso) ? ' noted' : ovr && eff ? ' ovr' : eff ? ' plan' : ''
    strip.push(
      <div key={i} className={'wday' + (iso === todayISO() ? ' today' : '')} {...tappable(() => dayOverrideSheet(iso))}>
        <div className="lbl">{t(DAYS[d.getDay()])}</div>
        <div className="num">{d.getDate()}</div>
        <div className={'dot' + dot} />
      </div>
    )
  }
  const wkEnd = new Date(wkStart); wkEnd.setDate(wkStart.getDate() + 6)
  const wkLabel = weekOffset === 0 ? t('This week') : `${wkStart.getDate()} ${wkStart.toLocaleDateString(dateLocale(), { month: 'short' })} – ${wkEnd.getDate()} ${wkEnd.toLocaleDateString(dateLocale(), { month: 'short' })}`

  const queue = queueView(S, todayISO())
  const rotating = scheduleModeOf(S) === 'rotation'
  const liveQ = queueOf(S)
  const plannerQueue = !!queue && !liveQ?.rotationId
  const managedQueue = !!liveQ && !!S.rotation && liveQ.rotationId === S.rotation.id
  const next = !S.active && !todayRoutines.length && !(rotating && !plannerQueue) ? nextTrainingDay(S, todayISO()) : null
  const { done: doneThisWeek, planned: plannedPerWeek } = weekTally(S, todayISO())
  const bwPoints = S.bodyweight.slice(-30).map(b => ({ t: b.t || new Date(b.d).getTime(), y: b.w, d: b.d }))

  const onToday = () => {
    if (S.active) nav('/workout')
    else if (todayRoutines.length) startFlow(effectiveRoutineIds(S, todayISO()))
    else dayOverrideSheet(todayISO())
  }
  const onQueueStart = id => { if (S.active) nav('/workout'); else startFlow([id]) }

  // PRs & Community data
  const prs = S.powerlifting?.prs || {}
  const unit = S.unit || 'kg'
  const feed = S.community?.activityFeed || []

  return (
    <div className="dashboard-content narrow">
      {/* Dashboard Top Header */}
      <div className="hdr"><img src="lifting-life-180.png" alt="Lifting Life" width="44" height="44" style={{ borderRadius: 12, flexShrink: 0 }} />
        <div>
          <h1>{user?.name ? t('Hi {0}', user.name) : 'Lifting Life'}</h1>
          <div className="sub">{today.toLocaleDateString(dateLocale(), { weekday: 'long', day: 'numeric', month: 'long' })}</div>
        </div>
        <button className="iconbtn" onClick={() => nav('/settings')} aria-label={trouble ? t('Settings') + ', ' + t('Connection problem') : t('Settings')}>
          <Icon name="gear" />{trouble && <span className="tab-dot" aria-hidden="true" />}
        </button>
      </div>

      {/* QUICK ACTIONS BAR (Requirement 2) */}
      <div className="dashboard-quick-actions">
        <button className="qaction-chip" onClick={() => nav('/workout')}>
          <Icon name="play" size={16} />
          <span>Start Workout</span>
        </button>
        <button className="qaction-chip" onClick={() => nav('/programs')}>
          <Icon name="clipboard" size={16} />
          <span>Create Program</span>
        </button>
        <button className="qaction-chip" onClick={() => nav('/library')}>
          <Icon name="dumbbell" size={16} />
          <span>Add Exercise</span>
        </button>
        <button className="qaction-chip" onClick={() => nav('/schedule')}>
          <Icon name="calendar" size={16} />
          <span>View Schedule</span>
        </button>
        <button className="qaction-chip" onClick={() => nav('/powerlifting')}>
          <Icon name="barbell" size={16} />
          <span>Log Lift</span>
        </button>
      </div>

      {/* UNIQUE FEATURE: LIFTPATH TRAINING TIMELINE (Requirement 2) */}
      <div className="liftpath-card card">
        <div className="liftpath-header">
          <div className="liftpath-title">
            <Icon name="chartLine" size={18} />
            <span>LiftPath™ Training Timeline</span>
          </div>
          <span className="liftpath-badge">Active Block</span>
        </div>

        <div className="liftpath-track">
          {/* Step 1: Recent Completed */}
          <div className="liftpath-step completed">
            <div className="step-marker">
              <Icon name="check" size={14} />
            </div>
            <div className="step-content">
              <span className="step-title">Last Session Done</span>
              <span className="step-sub">{S.workouts[0]?.name || 'Upper Strength'} • Checked</span>
            </div>
          </div>

          <div className="step-line done" />

          {/* Step 2: Today */}
          <div className={`liftpath-step ${doneToday ? 'completed' : 'current'}`}>
            <div className="step-marker">
              <Icon name={doneToday ? 'check' : 'play'} size={14} />
            </div>
            <div className="step-content">
              <span className="step-title">Today's Training</span>
              <span className="step-sub">{todayName || 'Rest & Recovery'}</span>
            </div>
          </div>

          <div className="step-line" />

          {/* Step 3: Upcoming Milestone */}
          <div className="liftpath-step upcoming">
            <div className="step-marker">
              <Icon name="target" size={14} />
            </div>
            <div className="step-content">
              <span className="step-title">Next Milestone</span>
              <span className="step-sub">Squat 145kg Single @ RPE 9</span>
            </div>
          </div>
        </div>
      </div>

      {/* Main Today / Calendar Schedule Card */}
      <div className="card">
        {rotating ? (
          queue ? <QueueRow S={S} today={todayISO()} onStart={onQueueStart} managed={managedQueue} /> : (
            <div className="empty">
              {t('No rotation yet. Add routines to it in Plan.')}
              <div style={{ marginTop: 10 }}>
                <Button size="sm" variant="tinted" onClick={() => nav('/plan')}>{t('Set up in Plan')}</Button>
              </div>
            </div>
          )
        ) : (
          <>
            <div className="row between" style={{ marginBottom: 8 }}>
              <button className="iconbtn" style={{ width: 30, height: 30, fontSize: 15 }} onClick={() => setWeekOffset(w => w - 1)} aria-label={t('Previous week')}><Icon name="chevronLeft" /></button>
              <div className="small muted" style={{ fontWeight: 500 }}>{wkLabel}</div>
              <button className="iconbtn" style={{ width: 30, height: 30, fontSize: 15 }} onClick={() => setWeekOffset(w => w + 1)} aria-label={t('Next week')}><Icon name="chevronRight" /></button>
            </div>
            <div className="week">{strip}</div>
          </>
        )}

        <div className="today-row" {...tappable(onToday)}>
          <div className="row" style={{ gap: 9, minWidth: 0 }}>
            <span className="lrow-i" style={{ background: S.active ? 'var(--orange)' : doneToday ? 'var(--surface-3)' : routine ? 'var(--acc)' : 'var(--surface-3)' }}>
              <Icon
                name={S.active ? (editingSaved ? 'pencil' : 'play') : doneToday ? 'checkCircle' : routine ? glyphOf(routine.emoji) : 'moon'}
                style={doneToday && !S.active ? { color: 'var(--green)' } : undefined}
              />
            </span>
            <div style={{ minWidth: 0 }}>
              <div className="lbl2">{t('Today')}</div>
              <div className="ttl">
                {S.active ? (editingSaved ? S.active.name : t('{0} (in progress)', S.active.name))
                  : doneToday ? (doneToday.name ? t('{0} (done)', doneToday.name) : t('Workout done'))
                  : routine ? todayName : t('Rest day')}
                {todayOvr && routine && !doneToday ? ' · ' + t('rescheduled') : ''}
              </div>
              {next && !doneToday && <div className="ss">{t('Next session: {0}, {1}', t(DAYN[next.weekday]), next.routine.name)}</div>}
            </div>
          </div>
          {S.active ? <span className="tag" style={{ color: 'var(--orange)', background: 'color-mix(in srgb,var(--orange) 16%,transparent)' }}>{editingSaved ? t('Edit') : t('Resume')}</span>
            : doneToday ? <span className="tag" style={{ color: 'var(--green)', background: 'color-mix(in srgb,var(--green) 16%,transparent)' }}>{t('Done')}</span>
            : routine ? <span className="tag acc">{t('Start')}</span>
            : <Icon name="plus" className="chev" />}
        </div>

        {!S.active && (
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: 4 }}>
            <Button size="sm" variant="ghost" className="dim" icon="swap" onClick={() => nav('/workout')}>
              {t('Choose a different workout')}
            </Button>
          </div>
        )}
      </div>

      {/* POWERLIFTING SBD PREVIEW CARD */}
      <div className="card tappable" style={{ cursor: 'pointer' }} {...tappable(() => nav('/powerlifting'))}>
        <div className="row between" style={{ marginBottom: 8 }}>
          <div className="row" style={{ gap: 8 }}>
            <span className="lrow-i" style={{ background: 'var(--green)' }}><Icon name="barbell" /></span>
            <div>
              <div className="lbl2">Competition Big 3</div>
              <div className="ttl">Powerlifting Records</div>
            </div>
          </div>
          <Icon name="chevronRight" className="chev" />
        </div>
        <div className="sbd-quick-row">
          <div className="sbd-quick-item">
            <span className="name">Squat</span>
            <span className="val">{prs.squat?.weight > 0 ? `${prs.squat.weight} ${unit}` : `—`}</span>
          </div>
          <div className="sbd-quick-item">
            <span className="name">Bench</span>
            <span className="val">{prs.bench?.weight > 0 ? `${prs.bench.weight} ${unit}` : `—`}</span>
          </div>
          <div className="sbd-quick-item">
            <span className="name">Deadlift</span>
            <span className="val">{prs.deadlift?.weight > 0 ? `${prs.deadlift.weight} ${unit}` : `—`}</span>
          </div>
        </div>
      </div>

      {/* GYM CHECK-IN */}
      {S.checkIn !== false && (
        <div className="card tappable" style={{ cursor: 'pointer' }} {...tappable(() => nav('/checkin'))}>
          <div className="row between">
            <div className="row" style={{ gap: 9 }}>
              <span className="lrow-i" style={{ background: 'var(--blue)' }}><Icon name="qr" /></span>
              <div>
                <div className="lbl2">{t('At the gym')}</div>
                <div className="ttl">{t('Check in')}</div>
              </div>
            </div>
            <Icon name="chevronRight" className="chev" />
          </div>
        </div>
      )}

      {/* STARTER PLAN IF EMPTY */}
      {!S.routines.length && !S.active && (
        <div className="card">
          <div className="row" style={{ gap: 10, marginBottom: 6 }}>
            <span className="lrow-i"><Icon name="calendar" /></span>
            <div className="big" style={{ fontSize: 22 }}>{t('Welcome to Lifting Life 2.0!')}</div>
          </div>
          <div className="muted small" style={{ marginBottom: 12 }}>{t('Set up your weekly routine to get going, or grab a ready-made starter plan.')}</div>
          <Button variant="primary" icon="clipboard" onClick={starterPlanSheet}>{t('Load starter plan')}</Button>
          <div style={{ height: 8 }} />
          <Button onClick={() => nav('/programs')}>{t('Build custom training program')}</Button>
        </div>
      )}

      {/* BODY WEIGHT CARD */}
      {S.showWeightCard !== false && (
        <div className="card">
          <div className="row between bw-head" style={{ marginBottom: 6 }}>
            <h2 style={{ margin: 0 }}>{t('Body weight')}</h2>
            <div className="row" style={{ gap: 8 }}>
              <Button size="sm" icon="target" style={S.targetW ? { color: 'var(--yellow)' } : undefined} onClick={goalSheet}>{S.targetW ? fmtNum(S.targetW) : t('Goal')}</Button>
              <Button size="sm" icon="plus" onClick={() => bwSheet()}>{t('Log')}</Button>
            </div>
          </div>
          {bw ? (
            <>
              <div className="row" style={{ gap: 8, alignItems: 'baseline' }}>
                <div className="big">{fmtNum(bw.w)} <span className="muted" style={{ fontSize: '1rem' }}>{S.unit}</span></div>
                {!!delta && (
                  <span className="small row" style={{ gap: 2, fontWeight: 500, color: bwDeltaColor(delta, bw.w) }}>
                    <Icon name={delta > 0 ? 'arrowUp' : 'arrowDown'} style={{ fontSize: 12 }} />
                    {fmtNum(Math.abs(delta))}
                  </span>
                )}
                <span className="dim small" style={{ marginInlineStart: 'auto' }}>{fmtDate(bw.d, true)}</span>
              </div>
              {S.targetW && (
                <div className="small row" style={{ color: 'var(--yellow)', marginTop: 4, gap: 5 }}>
                  <Icon name="target" style={{ fontSize: 13 }} />
                  <span>{t('Goal')} {fmtNum(S.targetW)} {S.unit} · {Math.abs(S.targetW - bw.w) < 0.05 ? t('reached!') : t(S.targetW > bw.w ? '{0} to gain' : '{0} to lose', fmtNum(Math.abs(S.targetW - bw.w)) + ' ' + S.unit)}</span>
                </div>
              )}
              <div className="chart" style={{ marginTop: 8 }}><LineChart points={bwPoints} h={130} unit={S.unit} goal={S.targetW} /></div>
              <div className="row" style={{ justifyContent: 'flex-end', marginTop: 4 }}>
                <Button size="sm" variant="ghost" trailingIcon="chevronRight" onClick={weighInsSheet}>{t('All weigh-ins')}</Button>
              </div>
            </>
          ) : (
            <div className="muted small">
              {S.weighIn === false
                ? t('No weigh-ins yet. Log your weight to start the curve.')
                : t("No weigh-ins yet. Log your weight to start the curve (we also ask before every workout).")}
            </div>
          )}
        </div>
      )}

      {/* STREAK & CONSISTENCY CARD */}
      <div className="card tappable" style={{ cursor: 'pointer' }} {...tappable(() => calendarSheet())}>
        <div className="row between">
          <div>
            <div className="row" style={{ gap: 7, fontSize: 22, fontWeight: 600, letterSpacing: '-.021em' }}>
              <Icon name="flame" style={{ color: 'var(--orange)' }} />
              {t('{0} week streak', streakWeeks(S))}
            </div>
            <div className="muted small" style={{ marginTop: 2 }}>{doneThisWeek}{plannedPerWeek ? ' / ' + plannedPerWeek : ''} {t('this week')} · {tn('{0} workout total', '{0} workouts total', S.workouts.length)}</div>
          </div>
          <Icon name="calendar" className="chev" style={{ fontSize: 20 }} />
        </div>
      </div>

      {/* COMMUNITY FEED SNEAK PEEK */}
      {feed.length > 0 && (
        <div className="card tappable" style={{ cursor: 'pointer' }} {...tappable(() => nav('/community'))}>
          <div className="row between" style={{ marginBottom: 8 }}>
            <div className="row" style={{ gap: 8 }}>
              <span className="lrow-i" style={{ background: 'var(--purple)' }}><Icon name="chat" /></span>
              <div>
                <div className="lbl2">Training Circle & Friends</div>
                <div className="ttl">Recent Activity</div>
              </div>
            </div>
            <Icon name="chevronRight" className="chev" />
          </div>
          <div className="feed-peek-item">
            <span className="feed-author">{feed[0].displayName}:</span>
            <span className="feed-text">{feed[0].text}</span>
          </div>
        </div>
      )}
    </div>
  )
}
