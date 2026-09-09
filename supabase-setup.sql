-- ============================================================
-- DRIFTZERO — OPINIONES REALES + MODERACIÓN SEGURA
-- Ejecutar en Supabase > SQL Editor
-- Administrador autorizado: tomugonza@gmail.com
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  name varchar(50) not null default 'Anónimo',
  rating smallint not null check (rating between 1 and 5),
  recommend varchar(20) not null default 'No respondió'
    check (recommend in ('Sí', 'Tal vez', 'No', 'No respondió')),
  tags text[] not null default '{}',
  review_text varchar(1200) not null
    check (char_length(review_text) between 3 and 1200),
  service varchar(80) not null default 'Servicio DriftZero',
  public_permission boolean not null default false,
  approved boolean not null default false,
  reviewed boolean not null default false,
  created_at timestamptz not null default now()
);

-- Compatible con una tabla creada con una versión anterior.
alter table public.reviews
  add column if not exists reviewed boolean not null default false;

create index if not exists reviews_public_feed_idx
  on public.reviews (approved, public_permission, created_at desc);

create index if not exists reviews_pending_idx
  on public.reviews (reviewed, created_at desc);

alter table public.reviews enable row level security;

-- Eliminar políticas anteriores/actuales para poder ejecutar el setup más de una vez.
drop policy if exists "Anyone can submit a pending review" on public.reviews;
drop policy if exists "Anyone can read approved public reviews" on public.reviews;
drop policy if exists "Admin can read all reviews" on public.reviews;
drop policy if exists "Admin can update reviews" on public.reviews;
drop policy if exists "Admin can delete reviews" on public.reviews;

-- Visitantes: pueden enviar reseñas, pero nunca autoaprobarlas ni marcarlas revisadas.
create policy "Anyone can submit a pending review"
on public.reviews
for insert
to anon
with check (approved = false and reviewed = false);

-- Visitantes: solo ven lo que fue aprobado y autorizado para publicar.
create policy "Anyone can read approved public reviews"
on public.reviews
for select
to anon
using (approved = true and public_permission = true);

-- Administrador autenticado: acceso de moderación.
create policy "Admin can read all reviews"
on public.reviews
for select
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'tomugonza@gmail.com'
);

create policy "Admin can update reviews"
on public.reviews
for update
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'tomugonza@gmail.com'
)
with check (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'tomugonza@gmail.com'
);

create policy "Admin can delete reviews"
on public.reviews
for delete
to authenticated
using (
  lower(coalesce(auth.jwt() ->> 'email', '')) = 'tomugonza@gmail.com'
);

-- Menor privilegio posible.
revoke all on table public.reviews from anon, authenticated;
grant select, insert on table public.reviews to anon;
grant select, update, delete on table public.reviews to authenticated;

-- Importante:
-- La web usa una Publishable Key. NO uses una Secret Key ni service_role en el frontend.
