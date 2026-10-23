import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const apiDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')

test('Vercel runtime refuses file-backed accounts before writing a signing secret', () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'gym-storage-policy-'))
  try {
    const dataDir = path.join(scratch, 'data')
    const result = spawnSync(process.execPath, ['server.js'], {
      cwd: apiDir,
      env: { ...process.env, VERCEL: '1', DATA_DIR: dataDir, PORT: '0' },
      encoding: 'utf8',
      timeout: 10000
    })
    assert.notEqual(result.status, 0)
    assert.match(result.stderr, /requires durable shared storage/)
    assert.equal(fs.existsSync(dataDir), false)
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true })
  }
})