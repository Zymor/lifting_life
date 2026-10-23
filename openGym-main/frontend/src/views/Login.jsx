import { useStore } from '../store/useStore.js'
import { useUI } from '../store/useUI.js'
import { webauthnOK, passkeyLogin, passkeyRegister, passkeyError, bio } from '../lib/api.js'
import { hasData } from '../store/useStore.js'
import { t } from '../lib/i18n.js'
import { DEMO, REPO } from '../lib/demo.js'
import { guestAllowed } from '../lib/guest.js'
import { finishRegistration } from '../lib/account-registration.js'
import { useState, useRef, useEffect } from 'react'
import Icon from '../components/Icon.jsx'
import { Button, Segmented } from '../components/ui.jsx'
import { askAddDeviceData } from '../sheets.jsx'
import { passwordOn, PasswordRegisterForm, openPasswordSignIn } from '../components/PasswordAuth.jsx'
import { openDeviceLinkRedeem } from '../components/Passkeys.jsx'

function RegisterSheet({ close }) {
  const { setUser, pushState, pullState, loadConfig } = useStore()
  const config = useStore(s => s.config)
  const [name, setName] = useState('')
  const [code, setCode] = useState('')
  const [busy, setBusy] = useState(false)
  const inviteOnly = !!config?.invite_only
  // A password is offered only where the instance allows it (#118), and is the only choice in a
  // browser that cannot make a passkey. Where both work, the passkey stays the first one.
  const pwOn = passwordOn(config)
  const [how, setHow] = useState(webauthnOK() ? 'passkey' : 'password')
  const ref = useRef(null)
  useEffect(() => { setTimeout(() => ref.current?.focus(), 250) }, [])
  // Boot already fetched this; retry here only if that attempt failed, so the invite field still
  // appears on an instance whose config arrived late rather than never.
  useEffect(() => { loadConfig() }, [loadConfig])
  const go = async () => {
    if (busy) return
    const n = name.trim()
    if (!n) { useUI.getState().toast(t('Enter a name')); return }
    if (inviteOnly && !code.trim()) { useUI.getState().toast(t('An invite code is required')); return }
    setBusy(true)
    let u
    try { u = await passkeyRegister(n, code.trim()) }
    catch (e) {
      if (e.name !== 'NotAllowedError' && e.name !== 'AbortError') useUI.getState().toast(passkeyError(e, t('Registration failed')))
      setBusy(false)
      return
    }
    try {
      await finishRegistration({
        user: u, setUser, close, hasLocalData: hasData(useStore.getState().S),
        pushState, pullState, getSync: () => useStore.getState().sync,
        notify: message => useUI.getState().toast(message)
      })
    } finally { setBusy(false) }
  }
  const choose = pwOn && webauthnOK() && <>
    <Segmented options={[{ value: 'passkey', label: t('Passkey'), icon: 'fingerprint' }, { value: 'password', label: t('Password'), icon: 'key' }]}
      value={how} onChange={setHow} />
    <div style={{ height: 12 }} />
  </>
  if (pwOn && how === 'password') return <>
    <h3>{t('Create your profile')}</h3>
    {choose}
    <div className="muted small" style={{ marginBottom: 14 }}>{t('Pick a name and a password. You sign in with both.')}</div>
    <div className="dim small" style={{ marginBottom: 14 }}>{t('Guest workouts stay on this device. Creating a profile will try to upload them; check sync status before relying on another device.')}</div>
    <PasswordRegisterForm close={close} inviteOnly={inviteOnly} name={name} setName={setName} code={code} setCode={setCode} />
  </>
  return <>
    <h3>{t('Create your profile')}</h3>
    {choose}
    <div className="muted small" style={{ marginBottom: 14 }}>{t('Pick a name, then confirm with {0}. The passkey lives on your device, so no password needed.', bio())}</div>
    <div className="dim small" style={{ marginBottom: 14 }}>{t('Guest workouts stay on this device. Creating a profile will try to upload them; check sync status before relying on another device.')}</div>
    <input ref={ref} className="input" placeholder={t('Your name')} maxLength={40} value={name} onChange={e => setName(e.target.value)} />
    {inviteOnly && <>
      <div style={{ height: 10 }} />
      <input className="input" placeholder={t('Invite code')} maxLength={40} value={code}
        onChange={e => setCode(e.target.value.toUpperCase())} style={{ letterSpacing: '.14em', fontWeight: 600, textAlign: 'center' }} />
      <div className="dim small" style={{ marginTop: 6 }}>{t('This app is invite-only. Enter the code you were given.')}</div>
    </>}
    <div style={{ height: 12 }} />
    <Button variant="primary" onClick={go} disabled={busy} aria-busy={busy}>{busy ? t('Creating passkey…') : t('Create passkey')}</Button>
  </>
}

function RecoverySheet({ close, passwordEnabled }) {
  return <>
    <h3>{t('Get back into your profile')}</h3>
    <div className="muted small" style={{ marginBottom: 14, lineHeight: 1.5 }}>
      {t('Use a sign-in method you already set up. Creating a new profile will not bring back the workouts in your old account.')}
    </div>
    <div className="card small" style={{ textAlign: 'left', lineHeight: 1.55, marginBottom: 12 }}>
      <strong>{t('Another signed-in device')}</strong><br />
      {t('On that device, open Settings → Account → Add another device to make a one-time code for a new passkey.')}
    </div>
    {passwordEnabled && <div className="card small" style={{ textAlign: 'left', lineHeight: 1.55, marginBottom: 12 }}>
      <strong>{t('Password or admin reset code')}</strong><br />
      {t('Sign in with your password. If you forgot it, ask your app admin for a one-time reset code, then choose “Have a reset code” on the password sign-in screen. Reset codes are not sent by e-mail.')}
    </div>}
    <div className="dim small" style={{ textAlign: 'left', lineHeight: 1.5, marginBottom: 14 }}>
      {t('If you lost every passkey and have no password or signed-in device, this app cannot automatically recover the account.')}
    </div>
    {passwordEnabled && <Button variant="primary" onClick={() => { close(); openPasswordSignIn() }}>{t('Sign in with password')}</Button>}
    <div style={{ height: 8 }} />
    <Button variant="ghost" onClick={close}>{t('Close')}</Button>
  </>
}

export default function Login() {
  const { setUser, adoptProfile, setGuest } = useStore()
  const config = useStore(s => s.config)
  const canGuest = guestAllowed(config)
  const pwOn = passwordOn(config)
  const [signingIn, setSigningIn] = useState(false)
  const register = () => useUI.getState().openSheet(close => <RegisterSheet close={close} />)
  const recovery = () => useUI.getState().openSheet(close => <RecoverySheet close={close} passwordEnabled={pwOn} />)
  const signIn = async () => {
    if (signingIn) return
    setSigningIn(true)
    let u
    try { u = await passkeyLogin() }
    catch (e) {
      if (e.name !== 'NotAllowedError' && e.name !== 'AbortError') useUI.getState().toast(passkeyError(e, t('Sign-in failed')))
      setSigningIn(false)
      return
    }
    setUser(u, { adopt: true })
    try { await adoptProfile(askAddDeviceData); useUI.getState().toast(t('Welcome back, {0}', u.name)) }
    catch { useUI.getState().toast(t('Signed in. Your device data has not synced yet; check the connection status.')) }
    finally { setSigningIn(false) }
  }
  const head = <>
    <div style={{ display: 'flex', justifyContent: 'center' }}><img src="lifting-life-mark-v2-180.png" alt="" width="112" height="112" style={{ borderRadius: 24 }} /></div>
    <h1 style={{ fontSize: 34, fontWeight: 700, letterSpacing: '-.028em', margin: '10px 0 4px' }}>Lifting Life</h1>
  </>
  const wrap = { display: 'flex', flexDirection: 'column', justifyContent: 'center', minHeight: '78vh', textAlign: 'center' }

  // Demo build: no backend to sign in against — the only way in is the local guest profile.
  if (DEMO) return (
    <div className="narrow" style={wrap}>
      {head}
      <div className="muted" style={{ marginBottom: 30 }}>{t('Live demo. Everything stays in this browser.')}</div>
      <Button variant="primary" icon="play" onClick={() => setGuest(true)}>{t('Start the demo')}</Button>
      <div className="card small muted" style={{ textAlign: 'start', marginTop: 16 }}>
        {t('This demo runs entirely in your browser on example data. Nothing is sent anywhere. Passkey sign-in and sync across your devices come with the Lifting Life server, which you get by self-hosting it.')}
      </div>
      <div className="dim small" style={{ marginTop: 22, lineHeight: 1.6 }}>
        <a href={REPO} target="_blank" rel="noopener">{t('Self-host it in a minute →')}</a>
      </div>
    </div>
  )

  return (
    <div className="narrow" style={wrap}>
      {head}
      <div className="muted" style={{ marginBottom: 34 }}>{t('Your workouts. Your weights. Your profile.')}</div>
      {webauthnOK() ? <>
        <Button variant="primary" icon="fingerprint" onClick={signIn} disabled={signingIn} aria-busy={signingIn}>{signingIn ? t('Signing in…') : t('Sign in with passkey')}</Button>
        <div style={{ height: 10 }} />
        {pwOn && <><Button icon="key" onClick={() => openPasswordSignIn()}>{t('Sign in with password')}</Button><div style={{ height: 10 }} /></>}
        <Button icon="plusCircle" onClick={register}>{t('Create new profile')}</Button>
        {/* Already signed in on another device: a code from there gives this one a passkey of
            its own (#95), instead of a new, empty profile. */}
        <div style={{ height: 10 }} />
        <Button variant="ghost" className="dim" icon="qr" onClick={openDeviceLinkRedeem}>{t('Use a code from your other device')}</Button>
        {canGuest && <div style={{ height: 4 }} />}
      </> : pwOn ? <>
        {/* Plain http on a LAN address, or a browser without passkey support: the password is
            the way in, and the only way to create a profile from here. */}
        <div className="card small muted" style={{ textAlign: 'start', marginBottom: 14 }}>{t("This browser doesn't support passkeys. Sign in with your name and password instead.")}</div>
        <Button variant="primary" icon="key" onClick={() => openPasswordSignIn()}>{t('Sign in with password')}</Button>
        <div style={{ height: 10 }} />
        <Button icon="plusCircle" onClick={register}>{t('Create new profile')}</Button>
        {canGuest && <div style={{ height: 10 }} />}
      </> : <div className="card small muted" style={{ textAlign: 'start' }}>{canGuest
        ? t("This browser doesn't do passkeys, but you can still use Lifting Life locally on this device.")
        // Without passkeys and without the guest entrance there is no way in from this browser,
        // so say that plainly instead of offering a local profile that cannot be created.
        : t("This browser doesn't support passkeys, and this instance requires an account. Try a browser or device with passkey support.")}</div>}
      {canGuest && <Button variant="ghost" className="dim" onClick={() => setGuest(true)}>{t('Continue without account')}</Button>}
      <Button variant="ghost" className="dim" onClick={recovery}>{t('Need help signing in?')}</Button>
      <div className="card small" style={{ textAlign: 'left', marginTop: 20, lineHeight: 1.55 }}>
        <strong>{t('Where your workouts live')}</strong>
        <div style={{ marginTop: 8 }}>{t('Guest workouts stay in this browser. After creating an account, check sync status before relying on another device.')}</div>
        <div style={{ marginTop: 6 }}>{t('Signed-in workouts reach your account only after the server confirms an upload.')}</div>
      </div>
      <div className="dim small" style={{ marginTop: 18, lineHeight: 1.5 }}>{pwOn ? t('Passkeys use {0}. A password works too, where passkeys do not.', bio()) : t('Passkeys use {0}. No passwords to remember.', bio())}</div>
      <div className="dim small" style={{ marginTop: 10, lineHeight: 1.5 }}>{pwOn
        ? t('Lost a passkey? Use another passkey or your password. Password reset needs a code from your app admin; e-mail is not used for recovery.')
        : t('Keep a second passkey or a signed-in device. If you lose every passkey, this app cannot recover the account automatically.')}</div>
    </div>
  )
}
