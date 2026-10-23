import { t } from './i18n-core.js'

// Authentication has already succeeded when this runs. Sync is a second, independent result:
// do not tell someone registration failed or their data moved when the first push did not land.
export async function finishRegistration({ user, setUser, close, hasLocalData, pushState, pullState, getSync, notify }) {
  setUser(user)
  close()
  let synced = false
  try {
    if (hasLocalData) await pushState()
    else await pullState()
    const sync = getSync()
    synced = !!sync && sync.status === 'ok' && !sync.pending && !sync.lastError && sync.lastSynced > 0
  } catch { /* the local copy remains available for a later sync */ }
  if (synced) {
    notify(hasLocalData
      ? t('Profile created. Your workouts are synced with your profile.')
      : t('Welcome, {0}', user.name))
  } else {
    notify(t('Profile created, but your data has not synced yet. It is still on this device. Check the connection status and try syncing again.'))
  }
  return synced
}
