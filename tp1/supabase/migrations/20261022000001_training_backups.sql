-- Additive migration: does not alter or delete existing tp1 tables or data.
create table if not exists public.lifting_life_training_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  schema_version integer not null default 1 check (schema_version = 1),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  updated_at timestamptz not null default now()
);
alter table public.lifting_life_training_backups enable row level security;
revoke all on public.lifting_life_training_backups from anon;
grant select, insert, update, delete on public.lifting_life_training_backups to authenticated;
drop policy if exists own_training_backup on public.lifting_life_training_backups;
create policy own_training_backup on public.lifting_life_training_backups
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
