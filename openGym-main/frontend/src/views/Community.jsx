import { useEffect, useState } from 'react'
import { useStore } from '../store/useStore.js'
import { api } from '../lib/api.js'
import { t } from '../lib/i18n.js'
import Icon from '../components/Icon.jsx'
import './community.css'

const EMPTY = { invite: null, friends: [], incoming: [], outgoing: [] }

export default function Community() {
  const user = useStore(s => s.user)
  const [friendState, setFriendState] = useState({ owner: null, data: EMPTY })
  // A stale response from an earlier account must never show its names after an account switch.
  const roster = friendState.owner === user?.id ? friendState.data : EMPTY
  const setRoster = data => setFriendState({ owner: user?.id || null, data })
  const [code, setCode] = useState('')
  const [loading, setLoading] = useState(!!user)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const refresh = async () => setRoster(await api('/api/friends'))
  useEffect(() => {
    setCode(''); setError(''); setNotice('')
    if (!user) { setRoster(EMPTY); setLoading(false); return }
    let live = true
    setRoster(EMPTY)
    setLoading(true)
    api('/api/friends').then(result => { if (live) { setRoster(result); setError('') } })
      .catch(e => { if (live) setError(e.message || t('Could not load friends. Try again.')) })
      .finally(() => { if (live) setLoading(false) })
    return () => { live = false }
  }, [user?.id])

  const act = async (path, body, success, method = 'POST') => {
    if (busy) return false
    setBusy(true); setError(''); setNotice('')
    try {
      const result = await api(path, { method, body: JSON.stringify(body || {}) })
      setRoster(result)
      setNotice(success)
      return true
    } catch (e) {
      setError(e.message || t('The request did not complete. Try again.'))
      return false
    } finally { setBusy(false) }
  }

  const sendRequest = async e => {
    e.preventDefault()
    const sent = await act('/api/friends/request', { code: code.trim() }, t('Friend request sent. It will appear here until they respond.'))
    if (sent) setCode('')
  }
  const copyCode = async () => {
    try { await navigator.clipboard.writeText(roster.invite.code); setNotice(t('Friend code copied. Share it privately.')); setError('') }
    catch { setError(t('Copy failed. Select and copy the code instead.')) }
  }

  return <div className="view community-view">
    <header className="page-header"><div className="page-title-wrap">
      <h1 className="page-title">{t('Friends')}</h1>
      <p className="page-subtitle">{t('Connect by sharing a private, one-use code.')}</p>
    </div></header>
    {!user ? <div className="card friend-panel friend-empty">
      <Icon name="personCircle" size={28} /><h2>{t('Sign in to connect with friends')}</h2>
      <p>{t('Guest workouts stay on this device. A synced account is needed to send and receive friend requests.')}</p>
    </div> : <>
      <div className="friend-privacy card"><Icon name="lock" size={17} /><span>{t('Friends can see your account name only. Your workouts, programs, and profile details are not shared.')}</span></div>
      {error && <div className="friend-alert error" role="alert">{error} <button type="button" onClick={() => { setError(''); refresh().catch(e => setError(e.message)) }}>{t('Retry')}</button></div>}
      {notice && <div className="friend-alert success" role="status">{notice}</div>}
      {loading ? <p className="friend-loading">{t('Loading friends…')}</p> : <>
        <div className="friend-columns">
          <section className="card friend-panel"><h2>{t('Invite someone')}</h2>
            <p>{t('Create a code and send it privately. It expires in 24 hours, works once, and can be revoked at any time.')}</p>
            {roster.invite ? <>
              <div className="friend-code"><code>{roster.invite.code}</code><button type="button" onClick={copyCode}>{t('Copy')}</button></div>
              <div className="friend-meta">{t('Expires')} {new Date(roster.invite.expires).toLocaleString()}</div>
              <div className="friend-actions">
                <button type="button" disabled={busy} onClick={() => act('/api/friends/invite', {}, t('New code created. Your previous code no longer works.'))}>{t('Replace code')}</button>
                <button type="button" disabled={busy} onClick={() => act('/api/friends/invite', {}, t('Code revoked.'), 'DELETE')}>{t('Revoke code')}</button>
              </div>
            </> : <button className="primary-action-btn" type="button" disabled={busy} onClick={() => act('/api/friends/invite', {}, t('Friend code created.'))}>{t('Create friend code')}</button>}
          </section>
          <section className="card friend-panel"><h2>{t('Add a friend')}</h2>
            <p>{t('Ask them for their friend code. Sending a request does not share your workout data.')}</p>
            <form onSubmit={sendRequest} className="friend-add-form">
              <label htmlFor="friend-code-input">{t('Friend code')}</label>
              <input id="friend-code-input" autoComplete="off" spellCheck="false" maxLength={24} value={code} onChange={e => setCode(e.target.value)} placeholder={t('Paste their code')} />
              <button className="primary-action-btn" type="submit" disabled={busy || !code.trim()}>{t('Send request')}</button>
            </form>
          </section>
        </div>
        <section className="friend-list-section"><h2>{t('Requests received')} <span>{roster.incoming.length}</span></h2>
          {roster.incoming.length ? roster.incoming.map(person => <div className="card friend-row" key={person.requestId}>
            <span className="friend-avatar"><Icon name="person" size={18} /></span><strong>{person.name}</strong>
            <div className="friend-actions">
              <button type="button" disabled={busy} onClick={() => act('/api/friends/accept', { requestId: person.requestId }, t('Friend request accepted.'))}>{t('Accept')}</button>
              <button type="button" disabled={busy} onClick={() => act('/api/friends/decline', { requestId: person.requestId }, t('Friend request declined.'))}>{t('Decline')}</button>
            </div>
          </div>) : <p className="friend-muted">{t('No requests received.')}</p>}
        </section>
        <section className="friend-list-section"><h2>{t('Requests sent')} <span>{roster.outgoing.length}</span></h2>
          {roster.outgoing.length ? roster.outgoing.map(person => <div className="card friend-row" key={person.requestId}>
            <span className="friend-avatar"><Icon name="person" size={18} /></span><strong>{person.name}</strong>
            <div className="friend-actions"><span className="friend-muted">{t('Waiting for reply')}</span><button type="button" disabled={busy} onClick={() => act('/api/friends/cancel', { requestId: person.requestId }, t('Friend request cancelled.'))}>{t('Cancel')}</button></div>
          </div>) : <p className="friend-muted">{t('No requests waiting for a reply.')}</p>}
        </section>
        <section className="friend-list-section"><h2>{t('Your friends')} <span>{roster.friends.length}</span></h2>
          {roster.friends.length ? roster.friends.map(person => <div className="card friend-row" key={person.id}>
            <span className="friend-avatar"><Icon name="person" size={18} /></span><strong>{person.name}</strong>
            <div className="friend-actions"><button type="button" disabled={busy} onClick={() => act('/api/friends/remove', { userId: person.id }, t('Friend removed.'))}>{t('Remove')}</button></div>
          </div>) : <p className="friend-muted">{t('No friends yet. Share a code to get started.')}</p>}
        </section>
        <p className="friend-footnote">{t('Activity feeds and training circles are not available yet. No workout is published automatically.')}</p>
      </>}
    </>}
  </div>
}
