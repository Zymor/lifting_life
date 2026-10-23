import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { t } from '../lib/i18n.js'
import Icon from '../components/Icon.jsx'

export default function Programs() {
  const navigate = useNavigate()
  const { S, update } = useStore()

  // Program Templates & Saved Programs
  const templates = [
    {
      id: 'pb-4day',
      name: 'Powerbuilding 4-Day Split',
      author: 'Lifting Life Staff',
      goal: 'Strength & Hypertrophy',
      level: 'Intermediate',
      duration: '8 Weeks',
      daysPerWeek: 4,
      saves: 1420,
      privacy: 'public',
      description: 'The ultimate blend of heavy Big 3 compound progression and bodybuilding volume for complete athletic physique.',
      schedule: [
        { day: 'Day 1 (Monday)', name: 'Upper Strength', exercises: ['Barbell Bench Press (5x3 @ RPE 8.5)', 'Barbell Bent Over Row (4x6)', 'Overhead Press (3x5)', 'Incline Dumbbell Press (3x8)'] },
        { day: 'Day 2 (Tuesday)', name: 'Lower Strength', exercises: ['Barbell Full Squat (5x3 @ RPE 8.5)', 'Romanian Deadlift (4x6)', 'Leg Press (3x10)', 'Standing Calf Raise (4x12)'] },
        { day: 'Day 3 (Wednesday)', name: 'Rest & Recovery', exercises: ['Light mobility & walking'] },
        { day: 'Day 4 (Thursday)', name: 'Upper Hypertrophy', exercises: ['Dumbbell Incline Bench (4x8)', 'Lat Pulldown (4x10)', 'Dumbbell Lateral Raise (4x12)', 'Cable Triceps Extension (3x12)'] },
        { day: 'Day 5 (Friday)', name: 'Lower Hypertrophy', exercises: ['Barbell Deadlift (3x5 @ RPE 8.0)', 'Bulgarian Split Squat (3x8/leg)', 'Hamstring Curl (4x10)', 'Seated Calf Raise (3x15)'] },
      ]
    },
    {
      id: 'ppl-6day',
      name: 'Push / Pull / Legs (PPL)',
      author: 'Alex Rivera (IPF Lifter)',
      goal: 'Maximum Muscle & Strength',
      level: 'Advanced',
      duration: '12 Weeks',
      daysPerWeek: 6,
      saves: 980,
      privacy: 'public',
      description: 'High-frequency 6-day split hitting every major muscle group twice per week with heavy and moderate wave cycles.',
      schedule: [
        { day: 'Day 1', name: 'Push A (Chest / Delts / Triceps)', exercises: ['Barbell Bench Press (4x5)', 'Overhead Dumbbell Press (3x8)', 'Dips (3x10)', 'Lateral Raises (4x15)'] },
        { day: 'Day 2', name: 'Pull A (Back / Biceps / Rear Delts)', exercises: ['Deadlift (1x5 + 3x5 back-off)', 'Weighted Pull-Up (4x6)', 'Chest Supported Row (3x10)', 'Barbell Curl (3x10)'] },
        { day: 'Day 3', name: 'Legs A (Quads / Glutes / Calves)', exercises: ['Barbell Squat (4x6)', 'Leg Press (3x12)', 'Walking Lunges (3x10/leg)', 'Calf Raises (4x15)'] },
      ]
    },
    {
      id: '531-strength',
      name: '5/3/1 Wave Progression Block',
      author: 'Jim W. Style',
      goal: 'Pure Strength & Powerlifting',
      level: 'Intermediate - Elite',
      duration: '4 Weeks (with Deload)',
      daysPerWeek: 4,
      saves: 2150,
      privacy: 'public',
      description: 'Slow, steady, and guaranteed strength gains using calculated 1RM percentages across 4-week microcycles.',
      schedule: [
        { day: 'Day 1', name: 'Squat Focus', exercises: ['Barbell Squat (5/3/1 Wave)', 'Leg Press (5x10)', 'Hanging Leg Raise (5x15)'] },
        { day: 'Day 2', name: 'Bench Press Focus', exercises: ['Barbell Bench Press (5/3/1 Wave)', 'Dumbbell Row (5x10)', 'Triceps Pushdown (5x12)'] },
        { day: 'Day 3', name: 'Deadlift Focus', exercises: ['Barbell Deadlift (5/3/1 Wave)', 'Front Squat (5x8)', 'Ab Wheel Rollout (4x10)'] },
        { day: 'Day 4', name: 'Overhead Press Focus', exercises: ['Standing Barbell OHP (5/3/1 Wave)', 'Chin-Ups (5x8)', 'Face Pulls (5x15)'] },
      ]
    }
  ]

  // State
  const [activeTab, setActiveTab] = useState('browse') // 'browse' | 'my-programs' | 'builder'
  const [selectedProgram, setSelectedProgram] = useState(null)
  const [remixModal, setRemixModal] = useState(false)
  const [remixProgram, setRemixProgram] = useState(null)
  const [remixedName, setRemixedName] = useState('')

  // Builder Form State
  const [builderName, setBuilderName] = useState('')
  const [builderDesc, setBuilderDesc] = useState('')
  const [builderGoal, setBuilderGoal] = useState('Strength & Hypertrophy')
  const [builderLevel, setBuilderLevel] = useState('Intermediate')
  const [builderDuration, setBuilderDuration] = useState('8 Weeks')
  const [builderDays, setBuilderDays] = useState(4)
  const [builderPrivacy, setBuilderPrivacy] = useState('private')

  const myPrograms = S.trainingPrograms?.programs || []

  // Trigger Program Remix
  const openRemix = (prog) => {
    setRemixProgram(prog)
    setRemixedName(`${prog.name} (My Remix)`)
    setRemixModal(true)
  }

  const handleConfirmRemix = () => {
    if (!remixProgram) return
    const cloned = {
      id: 'remix_' + Date.now(),
      name: remixedName,
      author: `${S.athleteProfile?.displayName || 'Me'} (Remixed from ${remixProgram.author})`,
      originalAuthor: remixProgram.author,
      goal: remixProgram.goal,
      level: remixProgram.level,
      duration: remixProgram.duration,
      daysPerWeek: remixProgram.daysPerWeek,
      description: remixProgram.description,
      schedule: JSON.parse(JSON.stringify(remixProgram.schedule)),
      isRemix: true,
      privacy: 'private',
    }

    update(state => {
      if (!state.trainingPrograms) state.trainingPrograms = { programs: [] }
      if (!state.trainingPrograms.programs) state.trainingPrograms.programs = []
      state.trainingPrograms.programs.unshift(cloned)
    })

    setRemixModal(false)
    setActiveTab('my-programs')
  }

  const handleSaveNewProgram = (e) => {
    e.preventDefault()
    const newProg = {
      id: 'prog_' + Date.now(),
      name: builderName || 'Custom Split',
      author: S.athleteProfile?.displayName || 'Me',
      goal: builderGoal,
      level: builderLevel,
      duration: builderDuration,
      daysPerWeek: +builderDays,
      privacy: builderPrivacy,
      description: builderDesc,
      schedule: [
        { day: 'Day 1', name: 'Primary Lift & Accessories', exercises: ['Barbell Squat (4x5)', 'Leg Press (3x10)'] },
        { day: 'Day 2', name: 'Upper Body Focus', exercises: ['Barbell Bench Press (4x5)', 'Barbell Row (4x8)'] },
      ]
    }

    update(state => {
      if (!state.trainingPrograms) state.trainingPrograms = { programs: [] }
      if (!state.trainingPrograms.programs) state.trainingPrograms.programs = []
      state.trainingPrograms.programs.unshift(newProg)
    })

    setActiveTab('my-programs')
  }

  return (
    <div className="view programs-view">
      {/* Header */}
      <header className="page-header">
        <div className="page-title-wrap">
          <h1 className="page-title">{t('Training Programs & Program Remix')}</h1>
          <p className="page-subtitle">Build, customize, and remix proven strength & bodybuilding programs</p>
        </div>
        <button
          className="primary-action-btn"
          onClick={() => setActiveTab('builder')}
        >
          <Icon name="plus" size={16} />
          <span>{t('Build New Program')}</span>
        </button>
      </header>

      {/* Tabs */}
      <div className="subnav-tabs">
        <button className={`subnav-tab ${activeTab === 'browse' ? 'active' : ''}`} onClick={() => setActiveTab('browse')}>
          <Icon name="globe" size={18} />
          <span>Program Library</span>
        </button>
        <button className={`subnav-tab ${activeTab === 'my-programs' ? 'active' : ''}`} onClick={() => setActiveTab('my-programs')}>
          <Icon name="folder" size={18} />
          <span>My Saved Programs ({myPrograms.length})</span>
        </button>
        <button className={`subnav-tab ${activeTab === 'builder' ? 'active' : ''}`} onClick={() => setActiveTab('builder')}>
          <Icon name="pencil" size={18} />
          <span>Visual Program Editor</span>
        </button>
      </div>

      {/* 1. Browse Programs */}
      {activeTab === 'browse' && (
        <div className="programs-grid">
          {templates.map(prog => (
            <div key={prog.id} className="program-card card">
              <div className="prog-header">
                <div className="prog-title-wrap">
                  <h3>{prog.name}</h3>
                  <span className="prog-author">Created by {prog.author}</span>
                </div>
                <span className="privacy-pill public">PUBLIC</span>
              </div>

              <p className="prog-desc">{prog.description}</p>

              <div className="prog-badges">
                <span className="pbadge"><Icon name="target" size={14} /> {prog.goal}</span>
                <span className="pbadge"><Icon name="bolt" size={14} /> {prog.level}</span>
                <span className="pbadge"><Icon name="clock" size={14} /> {prog.duration}</span>
                <span className="pbadge"><Icon name="calendar" size={14} /> {prog.daysPerWeek} Days/Wk</span>
              </div>

              {/* Schedule Preview */}
              <div className="prog-schedule-preview">
                <h4>Weekly Schedule:</h4>
                <div className="schedule-day-list">
                  {prog.schedule.map((s, idx) => (
                    <div key={idx} className="sched-row">
                      <span className="day-name">{s.day}:</span>
                      <span className="routine-title">{s.name}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Actions */}
              <div className="prog-card-actions">
                <button
                  className="remix-btn"
                  onClick={() => openRemix(prog)}
                  title="Copy and customize exercises while keeping attribution"
                >
                  <Icon name="repeat" size={16} />
                  <span>Program Remix</span>
                </button>
                <button
                  className="assign-calendar-btn"
                  onClick={() => navigate('/schedule')}
                >
                  <Icon name="calendar" size={16} />
                  <span>Assign to Calendar</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* 2. My Programs */}
      {activeTab === 'my-programs' && (
        <div className="my-programs-container">
          {myPrograms.length === 0 ? (
            <div className="empty-state-card card">
              <Icon name="clipboard" size={36} />
              <h3>No Custom Programs Yet</h3>
              <p>You can create a program from scratch or use <strong>Program Remix</strong> on any template.</p>
              <button className="primary-action-btn" onClick={() => setActiveTab('browse')}>
                Explore Program Library
              </button>
            </div>
          ) : (
            <div className="programs-grid">
              {myPrograms.map(prog => (
                <div key={prog.id} className="program-card card">
                  <div className="prog-header">
                    <div className="prog-title-wrap">
                      <h3>{prog.name}</h3>
                      <span className="prog-author">{prog.author}</span>
                    </div>
                    {prog.isRemix && <span className="privacy-pill remix">REMIXED</span>}
                  </div>
                  <p className="prog-desc">{prog.description}</p>
                  <div className="prog-badges">
                    <span className="pbadge">{prog.goal}</span>
                    <span className="pbadge">{prog.daysPerWeek} Days/Wk</span>
                  </div>
                  <div className="prog-card-actions">
                    <button className="assign-calendar-btn" onClick={() => navigate('/schedule')}>
                      <Icon name="calendar" size={16} />
                      <span>Attach to Calendar</span>
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* 3. Program Builder */}
      {activeTab === 'builder' && (
        <div className="builder-card card">
          <div className="builder-header">
            <h3>Visual Program Builder</h3>
            <p>Design a structured multi-week training cycle linked with the central exercise database.</p>
          </div>

          <form onSubmit={handleSaveNewProgram} className="builder-form">
            <div className="form-group">
              <label>Program Name</label>
              <input
                type="text"
                value={builderName}
                placeholder="e.g. Upper / Lower Power & Mass"
                onChange={e => setBuilderName(e.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Description & Objectives</label>
              <textarea
                value={builderDesc}
                placeholder="Explain the strategy, rest intervals, and progression rules..."
                onChange={e => setBuilderDesc(e.target.value)}
                rows="3"
              />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Training Goal</label>
                <select value={builderGoal} onChange={e => setBuilderGoal(e.target.value)}>
                  <option value="Strength & Powerlifting">Strength & Powerlifting</option>
                  <option value="Hypertrophy & Mass">Hypertrophy & Mass</option>
                  <option value="Powerbuilding">Powerbuilding</option>
                  <option value="Athletic Conditioning">Athletic Conditioning</option>
                </select>
              </div>

              <div className="form-group">
                <label>Experience Level</label>
                <select value={builderLevel} onChange={e => setBuilderLevel(e.target.value)}>
                  <option value="Beginner">Beginner</option>
                  <option value="Intermediate">Intermediate</option>
                  <option value="Advanced">Advanced</option>
                  <option value="Elite">Elite</option>
                </select>
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Duration</label>
                <input
                  type="text"
                  value={builderDuration}
                  onChange={e => setBuilderDuration(e.target.value)}
                  placeholder="e.g. 8 Weeks"
                />
              </div>

              <div className="form-group">
                <label>Training Days per Week</label>
                <input
                  type="number"
                  min="1"
                  max="7"
                  value={builderDays}
                  onChange={e => setBuilderDays(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Privacy & Sharing</label>
                <select value={builderPrivacy} onChange={e => setBuilderPrivacy(e.target.value)}>
                  <option value="private">Private (Only Me)</option>
                  <option value="friends">Friends Only</option>
                  <option value="public">Public (Publish to Community)</option>
                </select>
              </div>
            </div>

            <div className="builder-actions-row">
              <button type="button" className="btn-cancel" onClick={() => setActiveTab('browse')}>Cancel</button>
              <button type="submit" className="btn-confirm">Save Program</button>
            </div>
          </form>
        </div>
      )}

      {/* Program Remix Modal */}
      {remixModal && remixProgram && (
        <div className="search-overlay" onClick={() => setRemixModal(false)}>
          <div className="search-modal" onClick={e => e.stopPropagation()}>
            <div className="search-header">
              <span className="modal-title-text">Program Remix</span>
              <button className="search-close-btn" onClick={() => setRemixModal(false)}>✕</button>
            </div>

            <div className="remix-modal-body">
              <p>You are remixing <strong>{remixProgram.name}</strong> originally created by <strong>{remixProgram.author}</strong>.</p>
              <p className="remix-note">This creates your own editable copy while preserving author attribution.</p>

              <div className="form-group" style={{ marginTop: '16px' }}>
                <label>Your Remixed Program Name</label>
                <input
                  type="text"
                  value={remixedName}
                  onChange={e => setRemixedName(e.target.value)}
                  required
                />
              </div>

              <div className="modal-actions-bar">
                <button className="btn-cancel" onClick={() => setRemixModal(false)}>Cancel</button>
                <button className="btn-confirm" onClick={handleConfirmRemix}>Save My Remix</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

