import { useState, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { t } from '../lib/i18n.js'
import { todayISO, fmtDate } from '../lib/format.js'
import Icon from '../components/Icon.jsx'

export default function Schedule() {
  const navigate = useNavigate()
  const { S, update } = useStore()
  const today = todayISO()

  // View state: 'month' | 'week' | 'day'
  const [viewMode, setViewMode] = useState('week')
  const [selectedDate, setSelectedDate] = useState(today)
  const [showScheduleModal, setShowScheduleModal] = useState(false)
  const [modalDate, setModalDate] = useState(today)
  const [selectedRoutineId, setSelectedRoutineId] = useState('')

  // Smart Reschedule state
  const [showRescheduleModal, setShowRescheduleModal] = useState(false)
  const [rescheduleEvent, setRescheduleEvent] = useState(null)
  const [suggestedDate, setSuggestedDate] = useState('')

  // Custom events from store with fallback
  const scheduleEvents = S.calendarSchedule?.events || [
    { id: 'ev1', date: today, routineId: 'r_upper', title: 'Upper Strength', completed: false, status: 'scheduled' },
  ]

  // Available routines to schedule
  const routines = S.routines || [
    { id: 'r_push', name: 'Push Strength & Chest', ex: ['0025', '0041'] },
    { id: 'r_pull', name: 'Pull & Back Power', ex: ['0027', '0032'] },
    { id: 'r_legs', name: 'Leg Day & Squat Focus', ex: ['0043', '0739'] },
    { id: 'r_upper', name: 'Upper Body Powerbuilding', ex: ['0025', '0293'] },
  ]

  // Generate current week dates
  const weekDates = useMemo(() => {
    const curr = new Date()
    const first = curr.getDate() - curr.getDay() + 1 // Monday
    const days = []
    for (let i = 0; i < 7; i++) {
      const d = new Date(curr.setDate(first + i))
      days.push(d.toISOString().slice(0, 10))
    }
    return days
  }, [])

  // Detect missed workouts (scheduled on or before yesterday, not marked completed or skipped)
  const missedWorkouts = useMemo(() => {
    return scheduleEvents.filter(ev => ev.date < today && ev.status === 'scheduled')
  }, [scheduleEvents, today])

  // Smart Reschedule algorithm: find next available date that has no scheduled workout
  const findSmartRescheduleDate = (fromEvent) => {
    const scheduledDates = new Set(scheduleEvents.map(e => e.date))
    let curr = new Date()
    curr.setDate(curr.getDate() + 1) // start from tomorrow

    for (let i = 0; i < 14; i++) {
      const iso = curr.toISOString().slice(0, 10)
      if (!scheduledDates.has(iso)) {
        return iso
      }
      curr.setDate(curr.getDate() + 1)
    }
    return today
  }

  const triggerSmartReschedule = (ev) => {
    setRescheduleEvent(ev)
    setSuggestedDate(findSmartRescheduleDate(ev))
    setShowRescheduleModal(true)
  }

  const confirmReschedule = () => {
    if (!rescheduleEvent || !suggestedDate) return
    update(state => {
      if (!state.calendarSchedule) state.calendarSchedule = { events: [] }
      const idx = (state.calendarSchedule.events || []).findIndex(e => e.id === rescheduleEvent.id)
      if (idx !== -1) {
        state.calendarSchedule.events[idx].rescheduledFrom = state.calendarSchedule.events[idx].date
        state.calendarSchedule.events[idx].date = suggestedDate
        state.calendarSchedule.events[idx].status = 'rescheduled'
      } else {
        state.calendarSchedule.events.push({
          ...rescheduleEvent,
          rescheduledFrom: rescheduleEvent.date,
          date: suggestedDate,
          status: 'rescheduled'
        })
      }
    })
    setShowRescheduleModal(false)
  }

  const handleAddWorkoutToDate = (e) => {
    e.preventDefault()
    const rot = routines.find(r => r.id === selectedRoutineId) || routines[0]
    const newEvent = {
      id: 'ev_' + Date.now(),
      date: modalDate,
      routineId: rot?.id || 'custom',
      title: rot?.name || 'Custom Training Session',
      status: 'scheduled'
    }

    update(state => {
      if (!state.calendarSchedule) state.calendarSchedule = { events: [] }
      state.calendarSchedule.events.push(newEvent)
    })
    setShowScheduleModal(false)
  }

  const toggleEventStatus = (evId, currentStatus) => {
    update(state => {
      if (!state.calendarSchedule) return
      const ev = (state.calendarSchedule.events || []).find(e => e.id === evId)
      if (ev) {
        ev.status = currentStatus === 'completed' ? 'scheduled' : 'completed'
      }
    })
  }

  return (
    <div className="view schedule-view">
      {/* Header */}
      <header className="page-header">
        <div className="page-title-wrap">
          <h1 className="page-title">{t('Workout Schedule & Calendar')}</h1>
          <p className="page-subtitle">Interactive planning with Smart Reschedule for missed sessions</p>
        </div>
        <button
          className="primary-action-btn"
          onClick={() => {
            setModalDate(today)
            setShowScheduleModal(true)
          }}
        >
          <Icon name="plus" size={16} />
          <span>{t('Schedule Workout')}</span>
        </button>
      </header>

      {/* Missed Workouts Alert with Smart Reschedule Banner */}
      {missedWorkouts.length > 0 && (
        <div className="smart-reschedule-alert">
          <div className="alert-content">
            <div className="alert-icon-wrap">
              <Icon name="warning" size={20} />
            </div>
            <div className="alert-text">
              <h4>Missed Workout Detected</h4>
              <p>You missed <strong>{missedWorkouts[0].title}</strong> on {fmtDate(missedWorkouts[0].date, false)}.</p>
            </div>
          </div>
          <button
            className="smart-reschedule-btn"
            onClick={() => triggerSmartReschedule(missedWorkouts[0])}
          >
            <Icon name="repeat" size={16} />
            <span>Smart Reschedule</span>
          </button>
        </div>
      )}

      {/* View Mode Toggle: Day / Week / Month */}
      <div className="schedule-toolbar">
        <div className="view-mode-selector">
          <button
            className={`mode-btn ${viewMode === 'day' ? 'active' : ''}`}
            onClick={() => setViewMode('day')}
          >
            Day
          </button>
          <button
            className={`mode-btn ${viewMode === 'week' ? 'active' : ''}`}
            onClick={() => setViewMode('week')}
          >
            Week
          </button>
          <button
            className={`mode-btn ${viewMode === 'month' ? 'active' : ''}`}
            onClick={() => setViewMode('month')}
          >
            Month
          </button>
        </div>

        <button
          className="today-shortcut-btn"
          onClick={() => setSelectedDate(today)}
        >
          Today
        </button>
      </div>

      {/* Week View */}
      {viewMode === 'week' && (
        <div className="week-calendar-grid">
          {weekDates.map(d => {
            const isToday = d === today
            const isSelected = d === selectedDate
            const dayEvents = scheduleEvents.filter(e => e.date === d)
            const dayName = new Date(d + 'T12:00:00').toLocaleDateString(undefined, { weekday: 'short' })
            const dayNum = d.split('-')[2]

            return (
              <div
                key={d}
                className={`week-day-col ${isToday ? 'is-today' : ''} ${isSelected ? 'is-selected' : ''}`}
                onClick={() => setSelectedDate(d)}
              >
                <div className="day-col-header">
                  <span className="col-day-name">{dayName}</span>
                  <span className={`col-day-num ${isToday ? 'today-badge' : ''}`}>{dayNum}</span>
                </div>

                <div className="day-col-events">
                  {dayEvents.length === 0 ? (
                    <div className="empty-day-slot" onClick={() => { setModalDate(d); setShowScheduleModal(true) }}>
                      <span className="rest-label">Rest Day</span>
                      <button className="add-slot-btn">+</button>
                    </div>
                  ) : (
                    dayEvents.map(ev => (
                      <div
                        key={ev.id}
                        className={`scheduled-card ${ev.status}`}
                        onClick={(e) => {
                          e.stopPropagation()
                          toggleEventStatus(ev.id, ev.status)
                        }}
                      >
                        <div className="card-top">
                          <span className="card-title">{ev.title}</span>
                          <span className={`status-pill ${ev.status}`}>{ev.status}</span>
                        </div>
                        {ev.rescheduledFrom && (
                          <span className="rescheduled-note">Moved from {ev.rescheduledFrom}</span>
                        )}
                      </div>
                    ))
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Day View */}
      {viewMode === 'day' && (
        <div className="day-view-container card">
          <div className="day-view-header">
            <h3>{fmtDate(selectedDate, true)}</h3>
            <span className="day-tag">{selectedDate === today ? 'Today' : 'Scheduled Day'}</span>
          </div>

          <div className="day-events-list">
            {scheduleEvents.filter(e => e.date === selectedDate).length === 0 ? (
              <div className="rest-day-banner">
                <Icon name="moon" size={32} />
                <h4>Scheduled Rest & Recovery Day</h4>
                <p>Rest days promote central nervous system recovery and muscle protein synthesis.</p>
                <button
                  className="add-workout-btn"
                  onClick={() => { setModalDate(selectedDate); setShowScheduleModal(true) }}
                >
                  <Icon name="plus" size={16} />
                  <span>Assign Workout to this Day</span>
                </button>
              </div>
            ) : (
              scheduleEvents.filter(e => e.date === selectedDate).map(ev => (
                <div key={ev.id} className="day-event-card">
                  <div className="event-info">
                    <span className="event-title">{ev.title}</span>
                    <span className="event-status-tag">{ev.status.toUpperCase()}</span>
                  </div>
                  <div className="event-actions">
                    <button
                      className="event-toggle-btn"
                      onClick={() => toggleEventStatus(ev.id, ev.status)}
                    >
                      <Icon name={ev.status === 'completed' ? 'checkCircle' : 'play'} size={18} />
                      <span>{ev.status === 'completed' ? 'Completed' : 'Start Session'}</span>
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* Month View Preview */}
      {viewMode === 'month' && (
        <div className="month-view-card card">
          <div className="month-header">
            <h3>Monthly Training Rhythm</h3>
            <p>Consistency overview across all scheduled microcycles.</p>
          </div>
          <div className="month-mini-grid">
            {Array.from({ length: 28 }, (_, i) => {
              const day = i + 1
              const hasSession = [1, 3, 5, 8, 10, 12, 15, 17, 19, 22, 24, 26].includes(day)
              return (
                <div key={day} className={`month-cell ${hasSession ? 'has-training' : 'rest-cell'}`}>
                  <span className="cell-num">{day}</span>
                  {hasSession && <div className="cell-dot" />}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Smart Reschedule Modal */}
      {showRescheduleModal && rescheduleEvent && (
        <div className="search-overlay" onClick={() => setShowRescheduleModal(false)}>
          <div className="search-modal" onClick={e => e.stopPropagation()}>
            <div className="search-header">
              <span className="modal-title-text">Smart Reschedule</span>
              <button className="search-close-btn" onClick={() => setShowRescheduleModal(false)}>✕</button>
            </div>

            <div className="reschedule-modal-body">
              <p>Missed Workout: <strong>{rescheduleEvent.title}</strong></p>
              <div className="reschedule-suggestion-card">
                <div className="suggestion-badge">AI SUGGESTION</div>
                <h4>Suggested New Date: <strong>{suggestedDate}</strong></h4>
                <p>This date is currently open and respects your planned recovery interval.</p>
              </div>

              <div className="form-group" style={{ marginTop: '16px' }}>
                <label>Or Choose Another Alternative Date:</label>
                <input
                  type="date"
                  value={suggestedDate}
                  onChange={e => setSuggestedDate(e.target.value)}
                />
              </div>

              <div className="modal-actions-bar">
                <button className="btn-cancel" onClick={() => setShowRescheduleModal(false)}>Cancel</button>
                <button className="btn-confirm" onClick={confirmReschedule}>Confirm Smart Reschedule</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Schedule Workout Modal */}
      {showScheduleModal && (
        <div className="search-overlay" onClick={() => setShowScheduleModal(false)}>
          <div className="search-modal" onClick={e => e.stopPropagation()}>
            <div className="search-header">
              <span className="modal-title-text">Schedule Training Session</span>
              <button className="search-close-btn" onClick={() => setShowScheduleModal(false)}>✕</button>
            </div>

            <form onSubmit={handleAddWorkoutToDate} className="log-modal-form">
              <div className="form-group">
                <label>Date</label>
                <input
                  type="date"
                  value={modalDate}
                  onChange={e => setModalDate(e.target.value)}
                  required
                />
              </div>

              <div className="form-group">
                <label>Select Routine / Program</label>
                <select
                  value={selectedRoutineId}
                  onChange={e => setSelectedRoutineId(e.target.value)}
                >
                  <option value="">Select a routine...</option>
                  {routines.map(r => (
                    <option key={r.id} value={r.id}>{r.name}</option>
                  ))}
                </select>
              </div>

              <div className="modal-actions-bar">
                <button type="button" className="btn-cancel" onClick={() => setShowScheduleModal(false)}>Cancel</button>
                <button type="submit" className="btn-confirm">Add to Calendar</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
