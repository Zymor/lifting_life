import { useState, useEffect, useRef, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store/useStore.js'
import { CATALOGUE, searchExercises } from '../lib/exercises.js'
import { t } from '../lib/i18n.js'
import Icon from './Icon.jsx'

export default function UniversalSearch({ isOpen, onClose }) {
  const navigate = useNavigate()
  const S = useStore(s => s.S)
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState('all') // 'all' | 'exercises' | 'programs' | 'athletes'
  const inputRef = useRef(null)

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 50)
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
      setQuery('')
    }
    return () => { document.body.style.overflow = '' }
  }, [isOpen])

  // Keydown to close on Escape
  useEffect(() => {
    const handleKeyDown = e => {
      if (e.key === 'Escape' && isOpen) onClose()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, onClose])

  // Search Results
  const exerciseResults = useMemo(() => {
    if (!query.trim() || (filter !== 'all' && filter !== 'exercises')) return []
    return searchExercises(CATALOGUE, query).slice(0, 15)
  }, [query, filter])

  const programResults = useMemo(() => {
    if (!query.trim() || (filter !== 'all' && filter !== 'programs')) return []
    const q = query.toLowerCase()
    const builtIn = [
      { id: 'prog-powerbuilding', name: 'Powerbuilding 4-Day Split', description: 'Upper/Lower strength & hypertrophy' },
      { id: 'prog-ppl', name: 'Push / Pull / Legs (PPL)', description: 'Classic 6-day split for muscle & power' },
      { id: 'prog-531', name: '5/3/1 Strength Block', description: 'Wave periodization for Squat, Bench & Deadlift' },
      { id: 'prog-upper-lower', name: 'Upper / Lower Strength Split', description: '4-day power and athletic performance' }
    ]
    const userRoutines = (S.routines || []).map(r => ({ id: r.id, name: r.name, description: `${r.ex?.length || 0} exercises` }))
    return [...builtIn, ...userRoutines].filter(p => p.name.toLowerCase().includes(q) || (p.description && p.description.toLowerCase().includes(q)))
  }, [query, filter, S.routines])

  const athleteResults = useMemo(() => {
    if (!query.trim() || (filter !== 'all' && filter !== 'athletes')) return []
    const q = query.toLowerCase()
    const friends = S.community?.friends || []
    const directory = [
      { id: 'u_marcus', username: 'marcus_iron', displayName: 'Marcus Iron', bio: 'Powerlifter | 240kg Deadlift puller' },
      { id: 'u_alex', username: 'alex_lifts', displayName: 'Alex Rivera', bio: 'IPF 83kg | Road to 550kg total' },
      { id: 'u_sarah', username: 'sarah_strong', displayName: 'Sarah Chen', bio: 'Powerbuilding athlete & strength coach' },
      { id: 'u_david', username: 'david_beast', displayName: 'David Miller', bio: 'Squat specialist | 200kg squatter' }
    ]
    const merged = [...friends, ...directory]
    const seen = new Set()
    return merged.filter(a => {
      if (seen.has(a.id)) return false
      seen.add(a.id)
      return a.username?.toLowerCase().includes(q) || a.displayName?.toLowerCase().includes(q) || a.bio?.toLowerCase().includes(q)
    })
  }, [query, filter, S.community])

  if (!isOpen) return null

  const handleSelectExercise = (ex) => {
    onClose()
    navigate(`/library?ex=${ex.id}`)
  }

  const handleSelectProgram = () => {
    onClose()
    navigate('/programs')
  }

  const handleSelectAthlete = () => {
    onClose()
    navigate('/community')
  }

  const totalResults = exerciseResults.length + programResults.length + athleteResults.length

  return (
    <div className="search-overlay" onClick={onClose}>
      <div className="search-modal" onClick={e => e.stopPropagation()}>
        <div className="search-header">
          <Icon name="magnifier" className="search-icon" />
          <input
            ref={inputRef}
            type="text"
            className="search-input"
            placeholder={t('Search exercises, programs, athletes...')}
            value={query}
            onChange={e => setQuery(e.target.value)}
          />
          <button className="search-close-btn" onClick={onClose} aria-label="Close search">
            <kbd className="esc-badge">ESC</kbd>
          </button>
        </div>

        {/* Filters */}
        <div className="search-filters">
          <button className={`chip ${filter === 'all' ? 'active' : ''}`} onClick={() => setFilter('all')}>All</button>
          <button className={`chip ${filter === 'exercises' ? 'active' : ''}`} onClick={() => setFilter('exercises')}>Exercises ({exerciseResults.length})</button>
          <button className={`chip ${filter === 'programs' ? 'active' : ''}`} onClick={() => setFilter('programs')}>Programs ({programResults.length})</button>
          <button className={`chip ${filter === 'athletes' ? 'active' : ''}`} onClick={() => setFilter('athletes')}>Athletes ({athleteResults.length})</button>
        </div>

        {/* Results Area */}
        <div className="search-results-list">
          {!query.trim() ? (
            <div className="search-hint">
              <p>Type to search across <strong>1,300+ exercises</strong>, structured <strong>training programs</strong>, and the <strong>Lifting Life community</strong>.</p>
              <div className="quick-suggestions">
                <span className="suggestion-label">Quick search:</span>
                <button className="suggestion-pill" onClick={() => setQuery('Squat')}>Squat</button>
                <button className="suggestion-pill" onClick={() => setQuery('Bench')}>Bench</button>
                <button className="suggestion-pill" onClick={() => setQuery('Deadlift')}>Deadlift</button>
                <button className="suggestion-pill" onClick={() => setQuery('Powerbuilding')}>Powerbuilding</button>
              </div>
            </div>
          ) : totalResults === 0 ? (
            <div className="search-empty">
              <Icon name="magnifier" size={32} />
              <p>No results found for "{query}"</p>
              <span>Try checking for typos or searching by muscle group or equipment.</span>
            </div>
          ) : (
            <>
              {/* Exercise Results */}
              {exerciseResults.length > 0 && (
                <div className="result-group">
                  <div className="result-group-title">
                    <Icon name="dumbbell" size={16} />
                    <span>Exercises</span>
                  </div>
                  {exerciseResults.map(ex => (
                    <div key={ex.id} className="search-result-item" onClick={() => handleSelectExercise(ex)}>
                      <div className="result-item-main">
                        <span className="result-item-title">{ex.n}</span>
                        <span className="result-item-sub">{ex.tg || ex.bp} • {ex.eq || 'bodyweight'}</span>
                      </div>
                      <div className="result-item-action">
                        <span className="badge">View</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* Program Results */}
              {programResults.length > 0 && (
                <div className="result-group">
                  <div className="result-group-title">
                    <Icon name="clipboard" size={16} />
                    <span>Training Programs</span>
                  </div>
                  {programResults.map(prog => (
                    <div key={prog.id} className="search-result-item" onClick={() => handleSelectProgram(prog)}>
                      <div className="result-item-main">
                        <span className="result-item-title">{prog.name}</span>
                        <span className="result-item-sub">{prog.description}</span>
                      </div>
                      <div className="result-item-action">
                        <span className="badge">Program</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* Athlete Results */}
              {athleteResults.length > 0 && (
                <div className="result-group">
                  <div className="result-group-title">
                    <Icon name="person" size={16} />
                    <span>Athletes & Community</span>
                  </div>
                  {athleteResults.map(ath => (
                    <div key={ath.id} className="search-result-item" onClick={() => handleSelectAthlete(ath)}>
                      <div className="result-item-avatar">
                        <Icon name="person" size={18} />
                      </div>
                      <div className="result-item-main">
                        <span className="result-item-title">{ath.displayName || ath.username}</span>
                        <span className="result-item-sub">@{ath.username} • {ath.bio || 'Lifter'}</span>
                      </div>
                      <div className="result-item-action">
                        <span className="badge">Athlete</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}

