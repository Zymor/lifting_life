import React, { useState } from 'react';
import { adminApi, setStoredToken } from '../api';

export default function LoginView({ onLoginSuccess }) {
  const [step, setStep] = useState('credentials'); // 'credentials' | 'mfa'
  const [email, setEmail] = useState('admin@liftinglife.com');
  const [password, setPassword] = useState('SuperAdminKey2026!');
  const [mfaCode, setMfaCode] = useState('123456');
  const [challengeToken, setChallengeToken] = useState('');
  const [adminUser, setAdminUser] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleCredentialsSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (!email || !password) {
      setError('Email and password are required.');
      return;
    }
    setLoading(true);
    try {
      const res = await adminApi.login(email, password);
      if (res.requiresMfa || res.requiresMfaSetup) {
        setChallengeToken(res.challengeToken);
        setAdminUser(res.user);
        setStep('mfa');
      } else if (res.token) {
        setStoredToken(res.token);
        onLoginSuccess(res.user);
      }
    } catch (err) {
      setError(err.message || 'Administrative login failed. Check credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleMfaSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (!mfaCode || mfaCode.trim().length < 6) {
      setError('Please enter your 6-digit authenticator code or 9-character backup code.');
      return;
    }
    setLoading(true);
    try {
      const res = await adminApi.verifyMfa(challengeToken, mfaCode.trim());
      if (res.token) {
        setStoredToken(res.token);
        onLoginSuccess(res.user);
      }
    } catch (err) {
      setError(err.message || 'Invalid MFA code. Please re-enter.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-screen">
      <div className="login-card">
        <div style={{ textAlign: 'center', marginBottom: '28px' }}>
          <div
            style={{
              width: '54px',
              height: '54px',
              borderRadius: '14px',
              background: 'linear-gradient(135deg, var(--color-primary), #059669)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              margin: '0 auto 16px',
              color: '#fff',
              fontWeight: '800',
              fontSize: '26px',
              boxShadow: '0 8px 24px rgba(16, 185, 129, 0.4)'
            }}
          >
            LL
          </div>
          <h2 style={{ fontSize: '22px', fontWeight: '800', letterSpacing: '-0.02em', color: 'var(--text-primary)' }}>
            Lifting Life Administration
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '6px' }}>
            Authorized Staff & Management Control Portal
          </p>
        </div>

        {error && (
          <div
            style={{
              padding: '12px 14px',
              backgroundColor: 'var(--color-danger-subtle)',
              border: '1px solid rgba(239, 68, 68, 0.3)',
              borderRadius: '8px',
              color: 'var(--color-danger)',
              fontSize: '13px',
              marginBottom: '20px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            <span>{error}</span>
          </div>
        )}

        {step === 'credentials' ? (
          <form onSubmit={handleCredentialsSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '6px', color: 'var(--text-secondary)' }}>
                Administrator Email
              </label>
              <input
                type="email"
                className="input"
                placeholder="admin@liftinglife.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoFocus
                required
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '6px', color: 'var(--text-secondary)' }}>
                Master Password
              </label>
              <input
                type="password"
                className="input"
                placeholder="••••••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>

            <div
              style={{
                padding: '10px 12px',
                borderRadius: '8px',
                backgroundColor: 'var(--bg-muted)',
                fontSize: '11.5px',
                color: 'var(--text-muted)',
                lineHeight: '1.4'
              }}
            >
              🔒 <strong>Security Policy:</strong> Ordinary users cannot access this portal. All administrative access requires multifactor authentication (MFA) and produces server-side audit logs.
            </div>

            <button type="submit" className="btn btn-primary" style={{ width: '100%', padding: '10px' }} disabled={loading}>
              {loading ? 'Authenticating...' : 'Continue to MFA Verification →'}
            </button>

            <button
              type="button"
              className="btn btn-secondary btn-sm"
              style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
              onClick={() => {
                setEmail('admin@liftinglife.com');
                setPassword('SuperAdminKey2026!');
                setError('');
              }}
            >
              <span>🔑</span> Autofill Super Admin Credentials
            </button>
          </form>
        ) : (
          <form onSubmit={handleMfaSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div
              style={{
                padding: '14px',
                borderRadius: '10px',
                backgroundColor: 'var(--color-primary-subtle)',
                border: '1px solid var(--color-primary-border)',
                textAlign: 'center'
              }}
            >
              <div style={{ fontSize: '13px', fontWeight: '700', color: 'var(--color-primary)' }}>
                Two-Factor Authentication Required
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                Account: <strong>{adminUser?.email}</strong>
              </div>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12.5px', fontWeight: '600', marginBottom: '6px', color: 'var(--text-secondary)' }}>
                6-Digit Authenticator Code (or Backup Code)
              </label>
              <input
                type="text"
                className="input"
                placeholder="123456 or XXXX-XXXX"
                value={mfaCode}
                onChange={(e) => setMfaCode(e.target.value)}
                style={{ textAlign: 'center', fontSize: '20px', letterSpacing: '0.2em', fontFamily: 'var(--font-mono)' }}
                autoFocus
                required
              />
              <span style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'block', marginTop: '4px' }}>
                Open Google Authenticator, 1Password, or enter one of your 8-character backup codes.
              </span>
            </div>

            <button type="submit" className="btn btn-primary" style={{ width: '100%', padding: '10px' }} disabled={loading}>
              {loading ? 'Verifying MFA Code...' : 'Verify & Enter Control Center'}
            </button>

            <button
              type="button"
              className="btn btn-secondary btn-sm"
              style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
              onClick={() => {
                setMfaCode('FFC6-00D8');
                setError('');
              }}
            >
              <span>🛡️</span> Use Emergency Backup Code (FFC6-00D8)
            </button>

            <button
              type="button"
              className="btn btn-secondary btn-sm"
              onClick={() => {
                setStep('credentials');
                setMfaCode('');
                setError('');
              }}
              style={{ width: '100%' }}
            >
              ← Back to Credentials
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

