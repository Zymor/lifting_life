import React, { useState, useEffect } from 'react';
import { adminApi, getStoredToken, setStoredToken } from './api';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import LoginView from './components/LoginView';
import OverviewTab from './components/OverviewTab';
import UsersTab from './components/UsersTab';
import ExercisesTab from './components/ExercisesTab';
import ProgramsTab from './components/ProgramsTab';
import AnalyticsTab from './components/AnalyticsTab';
import ContentTab from './components/ContentTab';
import InvitationsTab from './components/InvitationsTab';
import AuditLogsTab from './components/AuditLogsTab';
import SettingsTab from './components/SettingsTab';

export default function App() {
  const [currentAdmin, setCurrentAdmin] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('overview');
  const [theme, setTheme] = useState(() => localStorage.getItem('lifting_admin_theme') || 'dark');

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('lifting_admin_theme', theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => (prev === 'dark' ? 'light' : 'dark'));
  };

  useEffect(() => {
    const checkAuth = async () => {
      const token = getStoredToken();
      if (!token) {
        setLoading(false);
        return;
      }
      try {
        const res = await adminApi.getMe();
        if (res && res.user) {
          setCurrentAdmin(res.user);
        } else {
          setStoredToken('');
        }
      } catch (err) {
        setStoredToken('');
      } finally {
        setLoading(false);
      }
    };

    checkAuth();

    const handleAuthExpired = () => {
      setCurrentAdmin(null);
    };

    window.addEventListener('admin_auth_expired', handleAuthExpired);
    return () => window.removeEventListener('admin_auth_expired', handleAuthExpired);
  }, []);

  const handleLoginSuccess = (adminUser) => {
    setCurrentAdmin(adminUser);
    setActiveTab('overview');
  };

  const handleLogout = async () => {
    try {
      await adminApi.logout();
    } catch (_) {
      // Ignore logout errors and clean local state
    }
    setStoredToken('');
    setCurrentAdmin(null);
  };

  if (loading) {
    return (
      <div style={{ display: 'flex', height: '100vh', alignItems: 'center', justifyContent: 'center', backgroundColor: 'var(--bg-main)', color: 'var(--text-muted)' }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ width: '40px', height: '40px', border: '3px solid var(--border)', borderTopColor: 'var(--color-primary)', borderRadius: '50%', animation: 'spin 1s linear infinite', margin: '0 auto 16px' }} />
          <p style={{ fontWeight: 600 }}>Authenticating Lifting Life Administration Session...</p>
        </div>
      </div>
    );
  }

  if (!currentAdmin) {
    return <LoginView onLoginSuccess={handleLoginSuccess} />;
  }

  return (
    <div className="admin-layout">
      <Sidebar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        currentAdmin={currentAdmin}
        onLogout={handleLogout}
        theme={theme}
        toggleTheme={toggleTheme}
      />
      <div className="main-content">
        <Header activeTab={activeTab} currentAdmin={currentAdmin} />
        <main className="page-body">
          {activeTab === 'overview' && <OverviewTab setActiveTab={setActiveTab} />}
          {activeTab === 'users' && <UsersTab />}
          {activeTab === 'exercises' && <ExercisesTab />}
          {activeTab === 'programs' && <ProgramsTab />}
          {activeTab === 'analytics' && <AnalyticsTab />}
          {activeTab === 'content' && <ContentTab />}
          {activeTab === 'invitations' && <InvitationsTab />}
          {activeTab === 'audit' && <AuditLogsTab />}
          {activeTab === 'settings' && <SettingsTab currentAdmin={currentAdmin} />}
        </main>
      </div>
    </div>
  );
}

