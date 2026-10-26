-- Schema penilaian owner. Idempotent: aman dijalankan berulang.
create extension if not exists "pgcrypto";

create table if not exists holdings (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index if not exists holdings_name_key on holdings (lower(name));

create table if not exists owners (
  id          uuid primary key default gen_random_uuid(),
  holding_id  uuid not null references holdings(id) on delete cascade,
  name        text not null,
  project     text,
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists owners_holding_idx on owners (holding_id);

create table if not exists assessments (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null references owners(id) on delete cascade,
  quarter           text not null check (quarter ~ '^\d{4}-Q[1-4]$'),
  model             text not null check (model in ('market_baru', 'market_existing')),
  payment_method    text not null check (payment_method in ('cash', 'scf', 'lc', 'top', 'termin', 'retention')),
  payment_tenor     int  not null check (payment_tenor between 0 and 365),
  paid_amount       numeric(18, 2) not null default 0,
  projection_value  numeric(18, 2) not null default 0,
  projection_notes  text,
  holding_score     numeric(5, 2) not null check (holding_score between 0 and 100),
  payment_score     numeric(5, 2) not null check (payment_score between 0 and 100),
  tenor_score       numeric(5, 2) not null check (tenor_score between 0 and 100),
  projection_score  numeric(5, 2) not null check (projection_score between 0 and 100),
  total_score       numeric(5, 2) not null,
  grade             text not null check (grade in ('A', 'B', 'C', 'D', 'E')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (owner_id, quarter, model)
);
create index if not exists assessments_owner_idx on assessments (owner_id, quarter desc);

create or replace function touch_updated_at() returns trigger as $$
begin
  new.updated_at := now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists holdings_touch on holdings;
create trigger holdings_touch before update on holdings
  for each row execute function touch_updated_at();

drop trigger if exists owners_touch on owners;
create trigger owners_touch before update on owners
  for each row execute function touch_updated_at();

drop trigger if exists assessments_touch on assessments;
create trigger assessments_touch before update on assessments
  for each row execute function touch_updated_at();

-- Migrasi dari skema bayar properti (kpr/installment) ke skema konstruksi.
-- Idempotent: drop lalu buat ulang constraint.
alter table assessments drop constraint if exists assessments_payment_method_check;
alter table assessments drop constraint if exists assessments_payment_tenor_check;

-- Nilai lama yang tidak punya padanan di skema konstruksi dipetakan ke 'termin'
-- supaya data historis tetap valid.
update assessments set payment_method = 'termin'
 where payment_method in ('kpr', 'installment', 'other');

alter table assessments
  add constraint assessments_payment_method_check
  check (payment_method in ('cash', 'scf', 'lc', 'top', 'termin', 'retention'));

-- Tenor lama dalam BULAN; konversi ke HARI (1 bulan = 30 hari, cap 365).
update assessments set payment_tenor = least(payment_tenor * 30, 365)
 where payment_tenor > 365;

alter table assessments
  add constraint assessments_payment_tenor_check
  check (payment_tenor between 0 and 365);
