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
  const [filter, setFilter] = useState('all') // 'all' | 'exercises' | 'programs'
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

  if (!isOpen) return null

  const handleSelectExercise = (ex) => {
    onClose()
    navigate(`/library?ex=${ex.id}`)
  }

  const handleSelectProgram = () => {
    onClose()
    navigate('/programs')
  }

  const totalResults = exerciseResults.length + programResults.length

  return (
    <div className="search-overlay" onClick={onClose}>
      <div className="search-modal" onClick={e => e.stopPropagation()}>
        <div className="search-header">
          <Icon name="magnifier" className="search-icon" />
          <input
            ref={inputRef}
            type="text"
            className="search-input"
            placeholder={t('Search exercises and programs...')}
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
        </div>

        {/* Results Area */}
        <div className="search-results-list">
          {!query.trim() ? (
            <div className="search-hint">
              <p>Type to search exercises and training programs. Friends are added with private codes.</p>
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

            </>
          )}
        </div>
      </div>
    </div>
  )
}

