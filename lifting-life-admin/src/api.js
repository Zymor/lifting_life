const API_BASE = import.meta.env?.VITE_API_URL || 
  (typeof window !== 'undefined' && window.location.port !== '4000' && window.location.port !== '3000'
    ? 'http://localhost:4000/api'
    : '/api');

export function getStoredToken() {
  return localStorage.getItem('lifting_life_admin_token') || '';
}

export function setStoredToken(token) {
  if (token) {
    localStorage.setItem('lifting_life_admin_token', token);
  } else {
    localStorage.removeItem('lifting_life_admin_token');
  }
}

async function request(endpoint, options = {}) {
  const token = getStoredToken();
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    ...options.headers
  };

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers
  });

  const data = await response.json().catch(() => null);

  if (!response.ok) {
    if (response.status === 401 && !endpoint.includes('/auth/login') && !endpoint.includes('/auth/verify-mfa')) {
      setStoredToken('');
      window.dispatchEvent(new CustomEvent('admin_auth_expired'));
    }
    const errorMsg = data?.error || `Request failed (${response.status})`;
    const error = new Error(errorMsg);
    error.status = response.status;
    error.data = data;
    throw error;
  }

  return data;
}

export const adminApi = {
  // Authentication & MFA
  login: (email, password) =>
    request('/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password })
    }),

  verifyMfa: (challengeToken, code) =>
    request('/admin/auth/verify-mfa', {
      method: 'POST',
      body: JSON.stringify({ challengeToken, code })
    }),

  getMe: () => request('/admin/auth/me'),

  logout: () =>
    request('/admin/auth/logout', { method: 'POST' }).finally(() => {
      setStoredToken('');
    }),

  // Dashboard & Analytics
  getStats: (range = 'all') => request(`/admin/stats?range=${range}`),

  // Users Management
  getUsers: (params = {}) => {
    const q = new URLSearchParams(params).toString();
    return request(`/admin/users?${q}`);
  },

  getUser: (id) => request(`/admin/users/${id}`),

  updateUserStatus: (id, status, reason = '') =>
    request(`/admin/users/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status, reason })
    }),

  updateUserRole: (id, role) =>
    request(`/admin/users/${id}/role`, {
      method: 'PATCH',
      body: JSON.stringify({ role })
    }),

  generateUserRecovery: (id) =>
    request(`/admin/users/${id}/recovery`, { method: 'POST' }),

  deleteUser: (id) =>
    request(`/admin/users/${id}`, { method: 'DELETE' }),

  // Exercises Management
  getExercises: (params = {}) => {
    const q = new URLSearchParams(params).toString();
    return request(`/admin/exercises?${q}`);
  },

  getExercise: (id) => request(`/admin/exercises/${id}`),

  createExercise: (data) =>
    request('/admin/exercises', {
      method: 'POST',
      body: JSON.stringify(data)
    }),

  updateExercise: (id, data) =>
    request(`/admin/exercises/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    }),

  togglePublishExercise: (id) =>
    request(`/admin/exercises/${id}/publish`, { method: 'PATCH' }),

  deleteExercise: (id) =>
    request(`/admin/exercises/${id}`, { method: 'DELETE' }),

  getExerciseDuplicates: () => request('/admin/exercises-duplicates'),

  // Workout Programs & Templates
  getPrograms: () => request('/admin/programs'),

  createProgram: (data) =>
    request('/admin/programs', {
      method: 'POST',
      body: JSON.stringify(data)
    }),

  updateProgram: (id, data) =>
    request(`/admin/programs/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    }),

  deleteProgram: (id) =>
    request(`/admin/programs/${id}`, { method: 'DELETE' }),

  getTemplates: () => request('/admin/templates'),

  // Platform Content & Settings
  getSettings: () => request('/admin/settings'),

  updateSetting: (key, value) =>
    request('/admin/settings', {
      method: 'PUT',
      body: JSON.stringify({ key, value })
    }),

  // Invitations
  getInvitations: () => request('/admin/invitations'),

  createInvitation: (email, role) =>
    request('/admin/invitations', {
      method: 'POST',
      body: JSON.stringify({ email, role })
    }),

  revokeInvitation: (id) =>
    request(`/admin/invitations/${id}`, { method: 'DELETE' }),

  // Audit Logs
  getAuditLogs: (params = {}) => {
    const q = new URLSearchParams(params).toString();
    return request(`/admin/audit-logs?${q}`);
  }
};

export const api = adminApi;

