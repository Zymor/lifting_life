import express from 'express';
import cors from 'cors';
import { initializeDatabase } from './db.js';
import { authRouter } from './routes/auth.js';
import { adminAuthRouter } from './routes/adminAuth.js';
import { adminApiRouter } from './routes/adminApi.js';
import { publicRouter } from './routes/public.js';

export function createApp() {
  initializeDatabase();

  const app = express();

  // Security Middlewares & Headers
  app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
  }));

  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // Request logger (in development)
  app.use((req, res, next) => {
    if (process.env.NODE_ENV !== 'test') {
      const now = new Date().toISOString().substring(11, 19);
      console.log(`[${now}] ${req.method} ${req.originalUrl}`);
    }
    next();
  });

  // Health check
  app.get('/api/health', (req, res) => {
    res.json({
      status: 'ok',
      service: 'Lifting Life Authorized Backend Platform',
      version: '2.0.0',
      timestamp: new Date().toISOString()
    });
  });

  // API Routes
  app.use('/api/auth', authRouter);
  app.use('/api/admin/auth', adminAuthRouter);
  app.use('/api/admin', adminApiRouter);
  app.use('/api/public', publicRouter);

  // 404 Handler
  app.use((req, res) => {
    res.status(404).json({ error: `Endpoint not found: ${req.method} ${req.originalUrl}` });
  });

  // Global Error Handler
  app.use((err, req, res, next) => {
    console.error('[Server Error]', err);
    res.status(err.status || 500).json({
      error: err.message || 'Internal Server Error'
    });
  });

  return app;
}

const PORT = process.env.PORT || 4000;

if (process.argv[1] && process.argv[1].endsWith('server.js')) {
  const app = createApp();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`=======================================================`);
    console.log(`   LIFTING LIFE AUTHORIZED BACKEND RUNNING ON :${PORT}   `);
    console.log(`   Health: http://localhost:${PORT}/api/health           `);
    console.log(`   Admin API: http://localhost:${PORT}/api/admin         `);
    console.log(`   Public API: http://localhost:${PORT}/api/public       `);
    console.log(`=======================================================`);
  });
}

