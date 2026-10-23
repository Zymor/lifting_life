// @vitest-environment happy-dom
import React, { act } from 'react'
import { createRoot } from 'react-dom/client'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import Community from './Community.jsx'

globalThis.IS_REACT_ACT_ENVIRONMENT = true
const mocks = vi.hoisted(() => ({ user: null, api: vi.fn() }))
vi.mock('../store/useStore.js', () => ({ useStore: selector => selector({ user: mocks.user }) }))
vi.mock('../lib/api.js', () => ({ api: mocks.api }))
const mounted = []
function mount() {
  const host = document.createElement('div')
  document.body.appendChild(host)
  const root = createRoot(host)
  mounted.push({ host, root })
  act(() => root.render(<Community />))
  return host
}
const button = (host, label) => [...host.querySelectorAll('button')].find(x => x.textContent === label)
beforeEach(() => { mocks.user = null; mocks.api.mockReset() })
afterEach(() => act(() => { for (const { host, root } of mounted.splice(0)) { root.unmount(); host.remove() } }))

it('tells guests that friends require an account and shows no invented activity', () => {
  const host = mount()
  expect(host.textContent).toContain('Sign in to connect with friends')
  expect(host.textContent).not.toContain('Alex Rivera')
  expect(mocks.api).not.toHaveBeenCalled()
})

it('shows only server roster and never claims a failed request was sent', async () => {
  mocks.user = { id: 'a', name: 'Athlete A' }
  mocks.api.mockImplementation(async (path, opts) => {
    if (path === '/api/friends' && !opts) return { invite: null, friends: [], incoming: [], outgoing: [] }
    throw new Error('Network unavailable')
  })
  const host = mount()
  await act(async () => {})
  expect(host.textContent).toContain('No friends yet')
  expect(host.textContent).not.toContain('Alex Rivera')
  // A mutation must surface its error instead of pretending the server accepted it.
  await act(async () => { button(host, 'Create friend code').click() })
  expect(host.textContent).toContain('Network unavailable')
  expect(host.textContent).not.toContain('Friend code created')
})

it('uses the committed mutation response without needing another GET', async () => {
  mocks.user = { id: 'a', name: 'Athlete A' }
  mocks.api.mockImplementation(async (path, opts) => {
    if (path === '/api/friends' && !opts) return { invite: null, friends: [], incoming: [], outgoing: [] }
    if (path === '/api/friends/invite' && opts?.method === 'POST') return {
      invite: { code: 'A'.repeat(24), expires: Date.now() + 3600000 }, friends: [], incoming: [], outgoing: []
    }
    throw new Error('unexpected request')
  })
  const host = mount()
  await act(async () => {})
  await act(async () => { button(host, 'Create friend code').click() })
  expect(host.textContent).toContain('A'.repeat(24))
  expect(host.textContent).toContain('Friend code created')
  expect(mocks.api.mock.calls.filter(([path]) => path === '/api/friends')).toHaveLength(1)
})
