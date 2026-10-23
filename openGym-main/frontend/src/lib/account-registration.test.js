import { describe, expect, it, vi } from 'vitest'
import { finishRegistration } from './account-registration.js'

vi.mock('./i18n-core.js', () => ({ t: (message, value) => message.replace('{0}', value ?? '') }))

const setup = (sync, overrides = {}) => {
  const calls = []
  const actions = {
    user: { id: 'u1', name: 'Ana' },
    setUser: u => calls.push(['user', u.id]),
    close: () => calls.push(['close']),
    hasLocalData: true,
    pushState: async () => calls.push(['push']),
    pullState: async () => calls.push(['pull']),
    getSync: () => sync,
    notify: message => calls.push(['notice', message]),
    ...overrides
  }
  return { calls, actions }
}

describe('registration result', () => {
  it('reports guest workouts as synced only after the push is confirmed', async () => {
    const { calls, actions } = setup({ status: 'ok', pending: false, lastError: null, lastSynced: 100 })
    expect(await finishRegistration(actions)).toBe(true)
    expect(calls.map(([kind]) => kind)).toEqual(['user', 'close', 'push', 'notice'])
    expect(calls.at(-1)[1]).toContain('workouts are synced')
  })

  it('keeps the account created when a push is pending or fails', async () => {
    const { calls, actions } = setup({ status: 'offline', pending: true, lastError: { code: 'network' }, lastSynced: 0 })
    expect(await finishRegistration(actions)).toBe(false)
    expect(calls.at(-1)[1]).toContain('still on this device')
    const thrown = setup(null, { pushState: async () => { throw new Error('offline') } })
    expect(await finishRegistration(thrown.actions)).toBe(false)
    expect(thrown.calls.at(-1)[1]).toContain('Profile created')
  })

  it('pulls an empty profile without claiming guest data moved', async () => {
    const { calls, actions } = setup({ status: 'ok', pending: false, lastError: null, lastSynced: 100 }, { hasLocalData: false })
    expect(await finishRegistration(actions)).toBe(true)
    expect(calls.map(([kind]) => kind)).toEqual(['user', 'close', 'pull', 'notice'])
    expect(calls.at(-1)[1]).toBe('Welcome, Ana')
  })

  it('does not claim success when sync state is absent or still unconfirmed', async () => {
    const missing = setup(undefined)
    expect(await finishRegistration(missing.actions)).toBe(false)
    const unconfirmed = setup({ status: 'ok', pending: false, lastError: null, lastSynced: 0 })
    expect(await finishRegistration(unconfirmed.actions)).toBe(false)
  })
})
