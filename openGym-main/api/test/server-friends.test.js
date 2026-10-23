import { test } from 'node:test'
import assert from 'node:assert/strict'
import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { boundPort } from './helpers.mjs'

const API = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')
const SECRET = crypto.randomBytes(32).toString('hex')
const users = ['a', 'b', 'c'].map(id => ({ id, name: `Athlete ${id.toUpperCase()}`, created: new Date().toISOString() }))
const cookie = id => {
  const payload = `${id}:${Date.now() + 3600000}:0`
  return `gymsid=${payload}.${crypto.createHmac('sha256', SECRET).update(payload).digest('base64url')}`
}

async function start(t, initial = {}) {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'gym-friends-'))
  fs.writeFileSync(path.join(dataDir, 'secret'), SECRET, { mode: 0o600 })
  fs.writeFileSync(path.join(dataDir, 'db.json'), JSON.stringify({ users, creds: [], subs: [], invites: [], ...initial }))
  const child = spawn(process.execPath, ['server.js'], {
    cwd: API, stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, PORT: '0', DATA_DIR: dataDir, ORIGIN: 'http://localhost:8080', RP_ID: 'localhost', VERCEL: '', VERCEL_URL: '' }
  })
  let log = ''
  child.stdout.on('data', d => { log += d })
  child.stderr.on('data', d => { log += d })
  t.after(() => { child.kill('SIGKILL'); fs.rmSync(dataDir, { recursive: true, force: true }) })
  const base = `http://127.0.0.1:${await boundPort(child, () => log)}`
  const req = async (method, route, id, body, headers = {}) => {
    const r = await fetch(base + route, {
      method,
      headers: { 'Content-Type': 'application/json', 'Sec-Fetch-Site': 'same-origin', ...(id ? { Cookie: cookie(id) } : {}), ...headers },
      body: body === undefined ? undefined : JSON.stringify(body)
    }).catch(e => { throw new Error(`${e.message}; cause: ${e.cause?.message} ${e.cause?.code}; server output: ${log}`) })
    return { status: r.status, body: await r.json() }
  }
  return { req, db: () => JSON.parse(fs.readFileSync(path.join(dataDir, 'db.json'), 'utf8')) }
}

test('friend codes require a session, are one-use, and never expose workout data', async t => {
  const h = await start(t)
  assert.equal((await h.req('GET', '/api/friends')).status, 401)
  assert.equal((await h.req('POST', '/api/friends/invite', null, {})).status, 401)
  assert.equal((await h.req('POST', '/api/friends/request', null, { code: 'x'.repeat(24) })).status, 401)
  const invited = await h.req('POST', '/api/friends/invite', 'a', {})
  assert.equal(invited.status, 201)
  const code = invited.body.invite.code
  assert.match(code, /^[A-Za-z0-9_-]{24}$/)
  assert.equal((await h.req('GET', '/api/friends', 'b')).body.invite, null)
  assert.equal((await h.req('POST', '/api/friends/request', 'a', { code })).status, 400) // self-add
  assert.equal((await h.req('POST', '/api/friends/request', 'b', { code })).status, 201)
  assert.equal((await h.req('POST', '/api/friends/request', 'c', { code })).status, 404) // consumed
  assert.equal((await h.req('POST', '/api/friends/request', 'b', { code })).status, 404)
  const a = (await h.req('GET', '/api/friends', 'a')).body
  const b = (await h.req('GET', '/api/friends', 'b')).body
  const c = (await h.req('GET', '/api/friends', 'c')).body
  assert.equal(a.incoming.length, 1)
  assert.equal(b.outgoing.length, 1)
  assert.deepEqual(c, { invite: null, friends: [], incoming: [], outgoing: [] })
  assert.deepEqual(Object.keys(a.incoming[0]).sort(), ['created', 'id', 'name', 'requestId'])
  assert.equal(JSON.stringify(a).includes('workout'), false)
  const requestId = a.incoming[0].requestId
  assert.equal((await h.req('POST', '/api/friends/accept', 'c', { requestId })).status, 404)
  assert.equal((await h.req('POST', '/api/friends/decline', 'c', { requestId })).status, 404)
  assert.equal((await h.req('POST', '/api/friends/cancel', 'a', { requestId })).status, 404)
  assert.equal((await h.req('POST', '/api/friends/accept', 'a', { requestId })).status, 200)
  assert.equal((await h.req('POST', '/api/friends/accept', 'a', { requestId })).status, 404)
  assert.deepEqual((await h.req('GET', '/api/friends', 'a')).body.friends, [{ id: 'b', name: 'Athlete B' }])
  assert.deepEqual((await h.req('GET', '/api/friends', 'b')).body.friends, [{ id: 'a', name: 'Athlete A' }])
  assert.deepEqual((await h.req('GET', '/api/friends', 'c')).body.friends, [])
  assert.equal((await h.req('POST', '/api/friends/remove', 'c', { userId: 'a' })).status, 404)
  assert.equal((await h.req('POST', '/api/friends/remove', 'b', { userId: 'a' })).status, 200)
  assert.equal(h.db().friendships.length, 0)
})

test('invite replacement and revocation invalidate the prior code; duplicates stay single', async t => {
  const h = await start(t)
  const old = (await h.req('POST', '/api/friends/invite', 'a', {})).body.invite.code
  const newer = (await h.req('POST', '/api/friends/invite', 'a', {})).body.invite.code
  assert.notEqual(old, newer)
  assert.equal((await h.req('POST', '/api/friends/request', 'b', { code: old })).status, 404)
  assert.equal((await h.req('POST', '/api/friends/request', 'b', { code: newer })).status, 201)
  const again = (await h.req('POST', '/api/friends/invite', 'a', {})).body.invite.code
  assert.equal((await h.req('POST', '/api/friends/request', 'b', { code: again })).status, 409)
  assert.equal(h.db().friendRequests.length, 1)
  assert.equal((await h.req('DELETE', '/api/friends/invite', 'a', {})).status, 200)
  assert.equal((await h.req('POST', '/api/friends/request', 'c', { code: again })).status, 404)
})

test('expired codes and cross-origin mutations are refused', async t => {
  const expired = { friendInvites: [{ userId: 'a', code: 'a'.repeat(24), expires: Date.now() - 1 }] }
  const h = await start(t, expired)
  assert.equal((await h.req('GET', '/api/friends', 'a')).body.invite, null)
  assert.equal((await h.req('POST', '/api/friends/request', 'b', { code: 'a'.repeat(24) })).status, 404)
  const r = await h.req('POST', '/api/friends/invite', 'a', {}, { 'Sec-Fetch-Site': 'cross-site', Origin: 'https://evil.example' })
  assert.equal(r.status, 403)
  assert.equal(h.db().friendInvites.length, 1)
})

test('disabled and deleted accounts disappear from friend lists and leave no social records', async t => {
  const h = await start(t, { users: users.map(u => u.id === 'a' ? { ...u, admin: true } : u) })
  const code = (await h.req('POST', '/api/friends/invite', 'c', {})).body.invite.code
  assert.equal((await h.req('POST', '/api/friends/request', 'b', { code })).status, 201)
  const requestId = (await h.req('GET', '/api/friends', 'c')).body.incoming[0].requestId
  assert.equal((await h.req('POST', '/api/friends/accept', 'c', { requestId })).status, 200)
  const newCode = (await h.req('POST', '/api/friends/invite', 'c', {})).body.invite.code
  assert.equal((await h.req('POST', '/api/admin/user/disable', 'a', { id: 'c', disabled: true })).status, 200)
  assert.deepEqual((await h.req('GET', '/api/friends', 'b')).body.friends, [])
  assert.equal((await h.req('POST', '/api/friends/request', 'b', { code: newCode })).status, 404)
  assert.equal(h.db().friendInvites.length, 0)
  assert.equal((await h.req('POST', '/api/admin/user/delete', 'a', { id: 'c' })).status, 200)
  assert.equal(h.db().friendships.length, 0)
  assert.equal(h.db().friendRequests.length, 0)
})
