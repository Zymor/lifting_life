import { useState, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { t } from '../lib/i18n.js'
import { todayISO } from '../lib/format.js'
import Icon from '../components/Icon.jsx'

export default function Powerlifting() {
  const navigate = useNavigate()
  const { S, update } = useStore()
  const unit = S.unit || 'kg'

  // Big 3 Lifts Data from Store with safe fallbacks
  const pl = S.powerlifting || {}
  const prs = pl.prs || {
    squat: { weight: 140, reps: 1, rpe: 9.5, date: '2026-10-15', e1rm: 142 },
    bench: { weight: 100, reps: 1, rpe: 9.0, date: '2026-10-18', e1rm: 102 },
    deadlift: { weight: 180, reps: 1, rpe: 9.5, date: '2026-10-12', e1rm: 184 },
  }

  // Active Tab: 'command' | 'calculator' | '1rm' | 'blocks'
  const [activeTab, setActiveTab] = useState('command')

  // Plate Calculator State
  const [targetWeight, setTargetWeight] = useState(140)
  const [barWeight, setBarWeight] = useState(pl.plateBarWeight || 20)

  // 1RM Calculator State
  const [calcWeight, setCalcWeight] = useState(120)
  const [calcReps, setCalcReps] = useState(5)
  const [calcRpe, setCalcRpe] = useState(8.5)

  // Log Powerlifting Session Modal State
  const [showLogModal, setShowLogModal] = useState(false)
  const [logLift, setLogLift] = useState('squat')
  const [logWeight, setLogWeight] = useState(120)
  const [logReps, setLogReps] = useState(5)
  const [logRpe, setLogRpe] = useState(8.5)
  const [logVariation, setLogVariation] = useState('competition') // 'competition' | 'paused' | 'tempo' | 'touch_and_go'

  // Epley 1RM Formula
  const estimated1RM = useMemo(() => {
    if (!calcWeight || !calcReps) return 0
    if (calcReps === 1) return calcWeight
    // Epley formula: w * (1 + r / 30)
    return Math.round(calcWeight * (1 + calcReps / 30))
  }, [calcWeight, calcReps])

  // Plate calculation
  const plateBreakdown = useMemo(() => {
    const netWeight = targetWeight - barWeight
    if (netWeight <= 0) return { platesPerSide: [], rem: 0 }
    const perSide = netWeight / 2
    const availablePlates = [25, 20, 15, 10, 5, 2.5, 1.25]
    const result = []
    let current = perSide

    for (const p of availablePlates) {
      const count = Math.floor(current / p)
      if (count > 0) {
        for (let i = 0; i < count; i++) {
          result.push(p)
        }
        current = current % p
      }
    }
    return { platesPerSide: result, rem: Math.round(current * 100) / 100 }
  }, [targetWeight, barWeight])

  // Handle logging session
  const handleSaveLog = (e) => {
    e.preventDefault()
    const e1rm = Math.round(logWeight * (1 + logReps / 30))
    const newSession = {
      id: 'pl_' + Date.now(),
      date: todayISO(),
      lift: logLift,
      weight: +logWeight,
      reps: +logReps,
      rpe: +logRpe,
      variation: logVariation,
      e1rm,
    }

    update(state => {
      if (!state.powerlifting) state.powerlifting = {}
      if (!state.powerlifting.sessions) state.powerlifting.sessions = []
      state.powerlifting.sessions.unshift(newSession)

      // Update PR if higher
      if (!state.powerlifting.prs) state.powerlifting.prs = {}
      const curPr = state.powerlifting.prs[logLift]
      if (!curPr || logWeight > (curPr.weight || 0) || (logWeight === curPr.weight && logReps > (curPr.reps || 0))) {
        state.powerlifting.prs[logLift] = {
          weight: +logWeight,
          reps: +logReps,
          rpe: +logRpe,
          date: todayISO(),
          e1rm,
        }
      }
    })

    setShowLogModal(false)
  }

  // Lift details config
  const liftCards = [
    {
      id: 'squat',
      title: 'Squat',
      subtitle: 'Competition Low / High Bar',
      pr: prs.squat || { weight: 0, reps: 0 },
      color: '#30d158',
      historyCount: 12,
      recent: '135kg × 3 @ RPE 8.5',
      trend: '+10kg past 30 days',
      nextDay: 'Tuesday (Lower Strength)'
    },
    {
      id: 'bench',
      title: 'Bench Press',
      subtitle: 'Competition Paused Bench',
      pr: prs.bench || { weight: 0, reps: 0 },
      color: '#0a84ff',
      historyCount: 16,
      recent: '95kg × 3 @ RPE 8.0',
      trend: '+5kg past 30 days',
      nextDay: 'Thursday (Upper Power)'
    },
    {
      id: 'deadlift',
      title: 'Deadlift',
      subtitle: 'Conventional / Sumo',
      pr: prs.deadlift || { weight: 0, reps: 0 },
      color: '#ff9f0a',
      historyCount: 9,
      recent: '175kg × 2 @ RPE 9.0',
      trend: '+12.5kg past 30 days',
      nextDay: 'Saturday (Deadlift & Pull)'
    }
  ]

  const totalPR = (prs.squat?.weight || 0) + (prs.bench?.weight || 0) + (prs.deadlift?.weight || 0)

  return (
    <div className="view powerlifting-view">
      {/* Header */}
      <header className="page-header">
        <div className="page-title-wrap">
          <h1 className="page-title">{t('Powerlifting Command Center')}</h1>
          <p className="page-subtitle">The Big 3: Squat, Bench Press, Deadlift tracking & progression</p>
        </div>
        <button className="primary-action-btn" onClick={() => setShowLogModal(true)}>
          <Icon name="plus" size={16} />
          <span>{t('Log Lift')}</span>
        </button>
      </header>

      {/* SBD Total Banner */}
      <div className="sbd-total-card">
        <div className="sbd-total-col">
          <span className="total-label">SBD Competition Total</span>
          <div className="total-val">
            <span className="num">{totalPR}</span>
            <span className="unit">{unit}</span>
          </div>
        </div>
        <div className="sbd-breakdown">
          <div className="sbd-item">
            <span className="name">Squat</span>
            <span className="val">{prs.squat?.weight || 0} {unit}</span>
          </div>
          <div className="sbd-sep">•</div>
          <div className="sbd-item">
            <span className="name">Bench</span>
            <span className="val">{prs.bench?.weight || 0} {unit}</span>
          </div>
          <div className="sbd-sep">•</div>
          <div className="sbd-item">
            <span className="name">Deadlift</span>
            <span className="val">{prs.deadlift?.weight || 0} {unit}</span>
          </div>
        </div>
      </div>

      {/* Tab Navigation */}
      <div className="subnav-tabs">
        <button className={`subnav-tab ${activeTab === 'command' ? 'active' : ''}`} onClick={() => setActiveTab('command')}>
          <Icon name="barbell" size={18} />
          <span>Lift Cards</span>
        </button>
        <button className={`subnav-tab ${activeTab === 'calculator' ? 'active' : ''}`} onClick={() => setActiveTab('calculator')}>
          <Icon name="calculator" size={18} />
          <span>Plate Calculator</span>
        </button>
        <button className={`subnav-tab ${activeTab === '1rm' ? 'active' : ''}`} onClick={() => setActiveTab('1rm')}>
          <Icon name="chartLine" size={18} />
          <span>1RM & Percentages</span>
        </button>
        <button className={`subnav-tab ${activeTab === 'blocks' ? 'active' : ''}`} onClick={() => setActiveTab('blocks')}>
          <Icon name="clipboard" size={18} />
          <span>Training Blocks</span>
        </button>
      </div>

      {/* 1. Command Center Cards */}
      {activeTab === 'command' && (
        <div className="lift-cards-grid">
          {liftCards.map(lift => (
            <div key={lift.id} className="lift-card">
              <div className="lift-card-header">
                <div className="lift-card-title">
                  <div className="lift-color-indicator" style={{ background: lift.color }} />
                  <h2>{lift.title}</h2>
                </div>
                <span className="lift-subtitle">{lift.subtitle}</span>
              </div>

              {/* Stats Grid */}
              <div className="lift-card-stats">
                <div className="lift-stat">
                  <span className="stat-label">Personal Record</span>
                  <div className="stat-value">
                    <span className="main-num">{lift.pr.weight || 0}</span>
                    <span className="unit-label">{unit}</span>
                    {lift.pr.reps > 1 && <span className="reps-tag">× {lift.pr.reps}</span>}
                  </div>
                </div>

                <div className="lift-stat">
                  <span className="stat-label">Estimated 1RM</span>
                  <div className="stat-value highlight">
                    <span className="main-num">{lift.pr.e1rm || lift.pr.weight || 0}</span>
                    <span className="unit-label">{unit}</span>
                  </div>
                </div>
              </div>

              <div className="lift-card-info-rows">
                <div className="info-row">
                  <Icon name="history" size={16} />
                  <span className="row-title">Recent Session:</span>
                  <span className="row-content">{lift.recent}</span>
                </div>
                <div className="info-row">
                  <Icon name="chartLine" size={16} />
                  <span className="row-title">Trend:</span>
                  <span className="row-content trend-positive">{lift.trend}</span>
                </div>
                <div className="info-row">
                  <Icon name="calendar" size={16} />
                  <span className="row-title">Next Scheduled:</span>
                  <span className="row-content">{lift.nextDay}</span>
                </div>
              </div>

              <div className="lift-card-actions">
                <button
                  className="card-action-btn"
                  onClick={() => {
                    setLogLift(lift.id)
                    setLogWeight(lift.pr.weight || 100)
                    setShowLogModal(true)
                  }}
                >
                  <Icon name="plus" size={16} />
                  <span>Log {lift.title}</span>
                </button>
                <button
                  className="card-action-btn secondary"
                  onClick={() => {
                    setTargetWeight(lift.pr.weight || 100)
                    setActiveTab('calculator')
                  }}
                >
                  <Icon name="calculator" size={16} />
                  <span>Plates</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* 2. Barbell Plate Calculator */}
      {activeTab === 'calculator' && (
        <div className="calculator-section card">
          <div className="calc-header">
            <h3>Visual Barbell Plate Calculator</h3>
            <p>Compute exact plates needed per side on the barbell collar.</p>
          </div>

          <div className="calc-inputs-row">
            <div className="input-group">
              <label>Target Weight ({unit})</label>
              <div className="num-input-wrap">
                <button onClick={() => setTargetWeight(w => Math.max(barWeight, w - 2.5))}>-2.5</button>
                <input
                  type="number"
                  value={targetWeight}
                  onChange={e => setTargetWeight(+e.target.value)}
                  step="2.5"
                />
                <button onClick={() => setTargetWeight(w => w + 2.5)}>+2.5</button>
              </div>
            </div>

            <div className="input-group">
              <label>Barbell Weight ({unit})</label>
              <select value={barWeight} onChange={e => setBarWeight(+e.target.value)}>
                <option value={20}>20 {unit} — Standard Olympic Men's Bar</option>
                <option value={15}>15 {unit} — Olympic Women's Bar</option>
                <option value={25}>25 {unit} — Heavy Squat / Trap Bar</option>
                <option value={10}>10 {unit} — Technique / EZ Bar</option>
              </select>
            </div>
          </div>

          {/* Graphical Barbell Collar */}
          <div className="barbell-visual">
            <div className="barbell-shaft">
              <span>{barWeight} {unit} Bar</span>
            </div>
            <div className="barbell-collar" />
            <div className="plates-stack">
              {plateBreakdown.platesPerSide.map((p, idx) => {
                const colorMap = {
                  25: '#ff3b30',
                  20: '#007aff',
                  15: '#ffcc00',
                  10: '#34c759',
                  5: '#ffffff',
                  2.5: '#000000',
                  1.25: '#8e8e93',
                }
                const heightMap = {
                  25: '90px',
                  20: '82px',
                  15: '72px',
                  10: '62px',
                  5: '52px',
                  2.5: '42px',
                  1.25: '34px',
                }
                return (
                  <div
                    key={idx}
                    className="visual-plate"
                    style={{
                      height: heightMap[p] || '60px',
                      backgroundColor: colorMap[p] || '#555',
                      color: p === 5 || p === 15 ? '#000' : '#fff'
                    }}
                  >
                    <span>{p}</span>
                  </div>
                )
              })}
            </div>
            <div className="barbell-end" />
          </div>

          {/* Breakdown List */}
          <div className="plate-summary">
            <h4>Each Side Needs:</h4>
            {plateBreakdown.platesPerSide.length === 0 ? (
              <p>Just the barbell collar (no plates).</p>
            ) : (
              <div className="plate-tags-row">
                {plateBreakdown.platesPerSide.map((p, i) => (
                  <span key={i} className="plate-pill">
                    {p} {unit}
                  </span>
                ))}
              </div>
            )}
            {plateBreakdown.rem > 0 && (
              <div className="plate-rem-warning">
                Note: Remainder of {plateBreakdown.rem} {unit} per side cannot be loaded with standard plates.
              </div>
            )}
          </div>
        </div>
      )}

      {/* 3. 1RM & Percentages Table */}
      {activeTab === '1rm' && (
        <div className="calculator-section card">
          <div className="calc-header">
            <h3>One-Repetition Maximum (1RM) Estimator</h3>
            <p>Calculate training percentages for wave periodization and programming.</p>
          </div>

          <div className="calc-inputs-row">
            <div className="input-group">
              <label>Weight Lifted ({unit})</label>
              <input
                type="number"
                value={calcWeight}
                onChange={e => setCalcWeight(+e.target.value)}
              />
            </div>
            <div className="input-group">
              <label>Repetitions Completed</label>
              <input
                type="number"
                value={calcReps}
                min="1"
                max="15"
                onChange={e => setCalcReps(+e.target.value)}
              />
            </div>
            <div className="input-group">
              <label>RPE (Rate of Perceived Exertion)</label>
              <select value={calcRpe} onChange={e => setCalcRpe(+e.target.value)}>
                <option value={10}>10 — Maximum Effort (0 reps left)</option>
                <option value={9.5}>9.5 — Maybe 1 rep left</option>
                <option value={9}>9.0 — Definite 1 rep left</option>
                <option value={8.5}>8.5 — 1-2 reps left</option>
                <option value={8}>8.0 — 2 reps left</option>
                <option value={7}>7.0 — 3 reps left (Speed / Warmup)</option>
              </select>
            </div>
          </div>

          <div className="e1rm-output-card">
            <span className="output-label">Estimated 1RM</span>
            <div className="output-num">
              <span>{estimated1RM}</span> <small>{unit}</small>
            </div>
          </div>

          {/* Percentage-based training table */}
          <div className="percentages-table-wrap">
            <h4>Training Intensity Zones</h4>
            <table className="percentages-table">
              <thead>
                <tr>
                  <th>Intensity %</th>
                  <th>Target Weight</th>
                  <th>Typical Rep Range</th>
                  <th>Focus Area</th>
                </tr>
              </thead>
              <tbody>
                {[
                  { pct: 95, reps: '1 - 2', focus: 'Maximal Strength / Peak' },
                  { pct: 90, reps: '2 - 3', focus: 'Heavy Working Singles/Triples' },
                  { pct: 85, reps: '4 - 5', focus: 'Strength Building' },
                  { pct: 80, reps: '6 - 8', focus: 'Powerbuilding / Volume' },
                  { pct: 75, reps: '8 - 10', focus: 'Hypertrophy' },
                  { pct: 70, reps: '10 - 12', focus: 'Endurance & Accessory' },
                  { pct: 60, reps: '12 - 15', focus: 'Dynamic Effort / Speed Sets' },
                ].map(row => (
                  <tr key={row.pct}>
                    <td className="bold">{row.pct}%</td>
                    <td className="weight-col bold">{Math.round((estimated1RM * row.pct) / 100 * 2) / 2} {unit}</td>
                    <td>{row.reps}</td>
                    <td className="text-muted">{row.focus}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* 4. Training Blocks */}
      {activeTab === 'blocks' && (
        <div className="blocks-section">
          <div className="blocks-header">
            <h3>Powerlifting & Strength Training Blocks</h3>
            <p>Configurable periodized structures for powerlifters and strength enthusiasts.</p>
          </div>

          <div className="blocks-grid">
            {[
              {
                id: 'powerbuilding',
                name: 'Powerbuilding 4-Day Split',
                description: 'Combines heavy Big 3 strength work with high-volume hypertrophy accessories.',
                days: 'Monday, Tuesday, Thursday, Friday',
                split: 'Upper Power • Lower Power • Upper Hypertrophy • Lower Hypertrophy'
              },
              {
                id: 'sbd-split',
                name: 'Squat, Bench, Deadlift (SBD) Competition Split',
                description: 'Specialized 3-day competition preparation with primary and paused variations.',
                days: 'Monday, Wednesday, Friday',
                split: 'Squat + Bench (Light) • Deadlift + Bench (Heavy) • Squat + Accessories'
              },
              {
                id: '531-wave',
                name: '5/3/1 Inspired Wave Periodization',
                description: 'Four-week microcycles with percentage escalation culminating in a deload.',
                days: '4 Days per week',
                split: 'Week 1: 3x5 (65/75/85%) • Week 2: 3x3 (70/80/90%) • Week 3: 5/3/1 (75/85/95%)'
              },
              {
                id: 'upper-lower-strength',
                name: 'Strength-Focused Upper / Lower Split',
                description: 'Balanced barbell progression designed to build foundational total and joint stability.',
                days: '4 Days per week',
                split: 'Heavy Upper • Heavy Lower • Volume Upper • Volume Lower'
              }
            ].map(b => (
              <div key={b.id} className="block-card card">
                <h4>{b.name}</h4>
                <p className="block-desc">{b.description}</p>
                <div className="block-meta">
                  <div className="meta-item">
                    <Icon name="calendar" size={14} />
                    <span>{b.days}</span>
                  </div>
                  <div className="meta-item">
                    <Icon name="list" size={14} />
                    <span>{b.split}</span>
                  </div>
                </div>
                <button
                  className="block-select-btn"
                  onClick={() => {
                    navigate('/programs')
                  }}
                >
                  <span>Build Program Template</span>
                  <Icon name="chevronRight" size={16} />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Log Lift Modal */}
      {showLogModal && (
        <div className="search-overlay" onClick={() => setShowLogModal(false)}>
          <div className="search-modal" onClick={e => e.stopPropagation()}>
            <div className="search-header">
              <span className="modal-title-text">Log Powerlifting Session</span>
              <button className="search-close-btn" onClick={() => setShowLogModal(false)}>✕</button>
            </div>

            <form onSubmit={handleSaveLog} className="log-modal-form">
              <div className="form-group">
                <label>Select Competition Lift</label>
                <select value={logLift} onChange={e => setLogLift(e.target.value)}>
                  <option value="squat">Squat (Competition / Low-Bar / High-Bar)</option>
                  <option value="bench">Bench Press (Competition Paused)</option>
                  <option value="deadlift">Deadlift (Conventional / Sumo)</option>
                </select>
              </div>

              <div className="form-group">
                <label>Lift Style / Variation</label>
                <select value={logVariation} onChange={e => setLogVariation(e.target.value)}>
                  <option value="competition">Competition Standard</option>
                  <option value="paused">Paused (2-3s pause at bottom / chest)</option>
                  <option value="tempo">Tempo (3-1-0 or 4-2-0 control)</option>
                  <option value="touch_and_go">Touch and Go</option>
                  <option value="deficit">Deficit / Raised Platform</option>
                </select>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Weight ({unit})</label>
                  <input
                    type="number"
                    step="0.5"
                    value={logWeight}
                    onChange={e => setLogWeight(e.target.value)}
                    required
                  />
                </div>
                <div className="form-group">
                  <label>Reps</label>
                  <input
                    type="number"
                    min="1"
                    max="30"
                    value={logReps}
                    onChange={e => setLogReps(e.target.value)}
                    required
                  />
                </div>
                <div className="form-group">
                  <label>RPE</label>
                  <select value={logRpe} onChange={e => setLogRpe(e.target.value)}>
                    <option value="10">10 (Max)</option>
                    <option value="9.5">9.5</option>
                    <option value="9">9.0</option>
                    <option value="8.5">8.5</option>
                    <option value="8">8.0</option>
                    <option value="7">7.0</option>
                  </select>
                </div>
              </div>

              <div className="modal-actions-bar">
                <button type="button" className="btn-cancel" onClick={() => setShowLogModal(false)}>Cancel</button>
                <button type="submit" className="btn-confirm">Save to Lift Record</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

