import React from 'react';

export default function Header({ activeTab, currentAdmin }) {
  const titles = {
    overview: 'Platform Dashboard Overview',
    users: 'Athlete & User Account Management',
    exercises: 'Universal Exercise Catalogue & Media',
    programs: 'Training Programs & Routine Templates',
    analytics: 'Performance & Training Analytics',
    content: 'Application Notices & Announcements',
    invitations: 'Administrative Access & Team',
    audit: 'Immutable Security Audit Logs',
    settings: 'Platform Infrastructure & Feature Flags'
  };

  return (
    <header className="top-header">
      <div className="header-left">
        <h2>{titles[activeTab] || 'Platform Management'}</h2>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '3px' }}>
          <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Lifting Life Platform</span>
          <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>•</span>
          <span style={{ fontSize: '11px', color: 'var(--color-primary)', fontWeight: '600' }}>
            Production Node Sync Active
          </span>
        </div>
      </div>

      <div className="header-right">
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '6px 12px',
            borderRadius: '9999px',
            backgroundColor: 'var(--color-primary-subtle)',
            border: '1px solid var(--color-primary-border)'
          }}
        >
          <span
            style={{
              width: '8px',
              height: '8px',
              borderRadius: '50%',
              backgroundColor: 'var(--color-primary)',
              display: 'inline-block',
              boxShadow: '0 0 8px var(--color-primary)'
            }}
          />
          <span style={{ fontSize: '12px', fontWeight: '700', color: 'var(--color-primary)' }}>
            System Status: 100% Operational
          </span>
        </div>

        {currentAdmin && (
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div
              style={{
                width: '36px',
                height: '36px',
                borderRadius: '50%',
                backgroundColor: 'var(--bg-card)',
                border: '1px solid var(--border-color)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontWeight: '700',
                fontSize: '13px',
                color: 'var(--color-primary)'
              }}
            >
              {(currentAdmin.displayName || currentAdmin.email)[0].toUpperCase()}
            </div>
          </div>
        )}
      </div>
    </header>
  );
}

