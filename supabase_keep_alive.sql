-- Keep-alive : génère une vraie écriture en base à chaque ping
-- pour que Supabase ne considère jamais le projet comme inactif.
-- À exécuter une seule fois dans Supabase > SQL Editor.

create table if not exists public.keep_alive (
    id smallint primary key default 1 check (id = 1),
    pinged_at timestamptz not null default now(),
    ping_count bigint not null default 0
);

insert into public.keep_alive (id) values (1) on conflict (id) do nothing;

-- Pas d'accès direct à la table depuis l'API publique
alter table public.keep_alive enable row level security;

-- Fonction appelée par le workflow GitHub (POST /rest/v1/rpc/keep_alive).
-- security definer : elle peut écrire même si la table est verrouillée par RLS,
-- et elle ne fait rien d'autre que mettre à jour une seule ligne.
create or replace function public.keep_alive()
returns timestamptz
language sql
security definer
set search_path = public
as $$
    update public.keep_alive
    set pinged_at = now(), ping_count = ping_count + 1
    where id = 1
    returning pinged_at;
$$;

revoke all on function public.keep_alive() from public;
grant execute on function public.keep_alive() to anon, authenticated;
