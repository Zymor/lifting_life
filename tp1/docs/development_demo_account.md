# Development demo account

This local fixture is automatically available in debug builds with APP_ENV=development (the default) and no Supabase URL or key. It is never created in Supabase. Start it with:

```powershell
flutter run
```

Credentials:

- Email: `demo.lifter.4821@example.com`
- Password: `V9!qR7#zL2@mK8`

Release/profile builds, staging/production environments, and builds with any Supabase configuration reject the demo account even if ENABLE_DEMO_ACCOUNT=true. Set ENABLE_DEMO_ACCOUNT=false to disable it in debug builds too. Stop the old running app and start again after changing launch flags; hot reload does not change compile-time settings.
