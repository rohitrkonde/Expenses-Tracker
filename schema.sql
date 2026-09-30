create extension if not exists pgcrypto;

create table if not exists public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'User', created_at timestamptz not null default now()
);
create table if not exists public.households (
 id uuid primary key default gen_random_uuid(), name text not null default 'Our Household',
 currency text not null default 'INR', created_at timestamptz not null default now()
);
create table if not exists public.household_members (
 household_id uuid not null references public.households(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 display_name text not null default 'Member', role text not null default 'member' check(role in('owner','member')),
 created_at timestamptz not null default now(), primary key(household_id,user_id)
);
create table if not exists public.accounts (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade default null,
 name text not null, type text not null default 'bank', opening_balance numeric(14,2) not null default 0, created_at timestamptz not null default now()
);
create table if not exists public.categories (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 name text not null, kind text not null default 'expense' check(kind in('expense','income','both')),
 created_at timestamptz not null default now(), unique(household_id,name)
);
create table if not exists public.transactions (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 type text not null check(type in('expense','income','transfer')), amount numeric(14,2) not null check(amount>=0),
 transaction_date date not null default current_date, category_id uuid references public.categories(id) on delete set null,
 account_id uuid references public.accounts(id) on delete set null, paid_by uuid references auth.users(id) on delete set null,
 merchant text, note text, tags text[] not null default '{}',
 created_by uuid not null default auth.uid() references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.budgets (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 month date not null, category_id uuid not null references public.categories(id) on delete cascade,
 amount numeric(14,2) not null default 0, rollover boolean not null default false, unique(household_id,month,category_id)
);
create table if not exists public.recurring_transactions (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 name text not null, amount numeric(14,2) not null, frequency text not null check(frequency in('weekly','monthly','yearly')),
 next_run date not null, category_id uuid references public.categories(id) on delete set null,
 account_id uuid references public.accounts(id) on delete set null, active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.goals (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 name text not null, target_amount numeric(14,2) not null, current_amount numeric(14,2) not null default 0, target_date date, created_at timestamptz not null default now()
);
create table if not exists public.settlements (
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 from_user uuid not null references auth.users(id), to_user uuid not null references auth.users(id),
 amount numeric(14,2) not null check(amount>0), settled_at date not null default current_date, note text, created_at timestamptz not null default now()
);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare h uuid;
begin
 insert into public.profiles(user_id,display_name) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'display_name',''),split_part(new.email,'@',1))) on conflict do nothing;
 insert into public.households(name) values('Our Household') returning id into h;
 insert into public.household_members(household_id,user_id,display_name,role) values(h,new.id,coalesce(nullif(new.raw_user_meta_data->>'display_name',''),split_part(new.email,'@',1)),'owner');
 insert into public.categories(household_id,name,kind) values
 (h,'Food','expense'),(h,'Groceries','expense'),(h,'Rent / EMI','expense'),(h,'Utilities','expense'),
 (h,'Transport','expense'),(h,'Shopping','expense'),(h,'Health','expense'),(h,'Entertainment','expense'),
 (h,'Bills & subscriptions','expense'),(h,'Education','expense'),(h,'Travel','expense'),(h,'Other','expense'),
 (h,'Salary','income'),(h,'Other income','income');
 return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_household_member(h uuid) returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.household_members where household_id=h and user_id=auth.uid()); $$;

create or replace function public.my_household_id() returns uuid language sql stable security definer set search_path=public
as $$ select household_id from public.household_members where user_id=auth.uid() limit 1 $$;

create or replace function public.add_household_member_by_email(p_email text,p_display_name text)
returns void language plpgsql security definer set search_path=public as $$
declare target uuid; h uuid;
begin
 select household_id into h from public.household_members where user_id=auth.uid() and role='owner' limit 1;
 if h is null then raise exception 'Household owner not found'; end if;
 select id into target from auth.users where lower(email)=lower(p_email) limit 1;
 if target is null then raise exception 'That email has not created an account yet'; end if;
 insert into public.household_members(household_id,user_id,display_name,role)
 values(h,target,coalesce(nullif(p_display_name,''),'Member'),'member')
 on conflict(household_id,user_id) do update set display_name=excluded.display_name;
end $$;

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.recurring_transactions enable row level security;
alter table public.goals enable row level security;
alter table public.settlements enable row level security;

create policy profiles_read on public.profiles for select using(user_id=auth.uid() or exists(select 1 from public.household_members hm join public.household_members me on me.household_id=hm.household_id where hm.user_id=profiles.user_id and me.user_id=auth.uid()));
create policy profiles_update on public.profiles for update using(user_id=auth.uid());
create policy households_read on public.households for select using(public.is_household_member(id));
create policy households_update on public.households for update using(exists(select 1 from public.household_members where household_id=id and user_id=auth.uid() and role='owner'));
create policy members_read on public.household_members for select using(public.is_household_member(household_id));
create policy members_insert on public.household_members for insert with check(exists(select 1 from public.household_members where household_id=household_members.household_id and user_id=auth.uid() and role='owner'));
create policy accounts_all on public.accounts for all using(public.is_household_member(household_id)) with check(public.is_household_member(household_id));
create policy categories_all on public.categories for all using(public.is_household_member(household_id)) with check(public.is_household_member(household_id));
create policy transactions_all on public.transactions for all using(public.is_household_member(household_id)) with check(public.is_household_member(household_id));
create policy budgets_all on public.budgets for all using(public.is_household_member(household_id)) with check(public.is_household_member(household_id));
create policy recurring_all on public.recurring_transactions for all using(public.is_household_member(household_id)) with check(public.is_household_member(household_id));
create policy goals_all on public.goals for all using(public.is_household_member(household_id)) with check(public.is_household_member(household_id));
create policy settlements_all on public.settlements for all using(public.is_household_member(household_id)) with check(public.is_household_member(household_id));

alter table public.accounts alter column household_id set default public.my_household_id();
alter table public.transactions alter column household_id set default public.my_household_id();
alter table public.budgets alter column household_id set default public.my_household_id();
alter table public.recurring_transactions alter column household_id set default public.my_household_id();
alter table public.goals alter column household_id set default public.my_household_id();
alter table public.settlements alter column household_id set default public.my_household_id();
