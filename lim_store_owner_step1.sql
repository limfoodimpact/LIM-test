-- LIM Food Impact
-- Step 1: approved store + owner account mapping foundation
-- Run ONCE in Supabase SQL Editor.
-- Existing store_inquiries / is_lim_admin() are preserved.

begin;

create table if not exists public.lim_stores (
  id uuid primary key default gen_random_uuid(),
  store_code text not null unique
    check (store_code ~ '^[a-z0-9][a-z0-9_-]{1,39}$'),
  store_name text not null
    check (char_length(trim(store_name)) between 1 and 80),
  region text not null default '',
  inquiry_id uuid unique references public.store_inquiries(id) on delete set null,
  owner_user_id uuid unique references auth.users(id) on delete set null,
  status text not null default 'approved'
    check (status in ('approved','paused','ended')),
  approved_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.lim_stores enable row level security;
revoke all on public.lim_stores from public, anon, authenticated;

-- Admin: approve/create a store record from an existing application.
-- Account linkage is deliberately separate: never create passwords in SQL/HTML.
create or replace function public.approve_store_inquiry(
  p_inquiry_id uuid,
  p_store_code text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inquiry public.store_inquiries%rowtype;
  v_store_id uuid;
  v_code text := lower(trim(p_store_code));
begin
  if auth.uid() is null or not public.is_lim_admin() then
    raise exception '운영자 권한이 없습니다.' using errcode='42501';
  end if;

  if v_code is null or v_code !~ '^[a-z0-9][a-z0-9_-]{1,39}$' then
    raise exception '매장 코드는 영문 소문자, 숫자, -, _ 만 사용할 수 있습니다.';
  end if;

  select * into v_inquiry
  from public.store_inquiries
  where id = p_inquiry_id
  for update;

  if not found then
    raise exception '해당 신청을 찾을 수 없습니다.';
  end if;

  if exists (
    select 1 from public.lim_stores
    where store_code = v_code and inquiry_id is distinct from p_inquiry_id
  ) then
    raise exception '이미 사용 중인 매장 코드입니다.';
  end if;

  insert into public.lim_stores(store_code, store_name, region, inquiry_id, status)
  values(v_code, trim(v_inquiry.store), trim(v_inquiry.region), v_inquiry.id, 'approved')
  on conflict (inquiry_id) do update
    set store_code = excluded.store_code,
        store_name = excluded.store_name,
        region = excluded.region,
        status = 'approved',
        approved_at = now()
  returning id into v_store_id;

  update public.store_inquiries
  set status = '참여 확정'
  where id = p_inquiry_id;

  return v_store_id;
end;
$$;

-- Admin: after a Supabase Auth owner account exists, connect it to one store.
create or replace function public.link_store_owner(
  p_store_id uuid,
  p_owner_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_lim_admin() then
    raise exception '운영자 권한이 없습니다.' using errcode='42501';
  end if;

  if not exists (select 1 from auth.users where id = p_owner_user_id) then
    raise exception '해당 사장님 계정을 찾을 수 없습니다.';
  end if;

  update public.lim_stores
  set owner_user_id = p_owner_user_id
  where id = p_store_id;

  if not found then
    raise exception '해당 매장을 찾을 수 없습니다.';
  end if;

  return true;
end;
$$;

-- Logged-in owner: return only their own approved store.
create or replace function public.get_my_store()
returns table (
  id uuid,
  store_code text,
  store_name text,
  region text,
  status text
)
language sql
security definer
set search_path = ''
as $$
  select s.id, s.store_code, s.store_name, s.region, s.status
  from public.lim_stores s
  where s.owner_user_id = auth.uid()
    and s.status = 'approved'
  limit 1;
$$;

revoke all on function public.approve_store_inquiry(uuid,text) from public, anon, authenticated;
revoke all on function public.link_store_owner(uuid,uuid) from public, anon, authenticated;
revoke all on function public.get_my_store() from public, anon, authenticated;

grant execute on function public.approve_store_inquiry(uuid,text) to authenticated;
grant execute on function public.link_store_owner(uuid,uuid) to authenticated;
grant execute on function public.get_my_store() to authenticated;

commit;
