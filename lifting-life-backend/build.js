#!/usr/bin/env node
import { execSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const frontendDir = path.resolve(__dirname, '../openGym-main/frontend')
const outDir = path.resolve(__dirname, 'dist')

console.log('Building Lifting Life frontend from:', frontendDir)
execSync('npm install', { cwd: frontendDir, stdio: 'inherit' })
execSync('npm run build', { cwd: frontendDir, stdio: 'inherit' })

const distSource = path.join(frontendDir, 'dist')
if (fs.existsSync(distSource)) {
  fs.rmSync(outDir, { recursive: true, force: true })
  fs.cpSync(distSource, outDir, { recursive: true })
  console.log('Successfully staged build to lifting-life-backend/dist')
} else {
  console.error('frontend/dist was not produced!')
  process.exit(1)
}
