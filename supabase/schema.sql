-- EnergyIQ database schema (Supabase / PostgreSQL)
-- Matches the report tables: USER, ZONE, DEVICE, ENERGY READING, ALERT.
-- Run once in Supabase → SQL Editor → New query → paste → Run.
-- Safe to run again: it drops and recreates everything (test data is lost).

-- ── Clean start ──────────────────────────────────────────────
drop function if exists public.ingest_reading cascade;
drop function if exists public.handle_new_user cascade;
drop table if exists public.alerts cascade;
drop table if exists public.energy_readings cascade;
drop table if exists public.devices cascade;
drop table if exists public.zones cascade;
drop table if exists public.profiles cascade;

-- ── Table 1: USER (profile; passwords are stored hashed by Supabase Auth) ──
create table public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  full_name  varchar(100) not null,
  email      varchar(255) not null unique,
  created_at timestamptz  not null default now()
);

-- ── Table 2: ZONE ────────────────────────────────────────────
create table public.zones (
  zone_id    uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(user_id) on delete cascade,
  zone_name  varchar(100) not null,
  location   varchar(150),
  status     varchar(10) not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now()
);

-- ── Table 3: DEVICE ──────────────────────────────────────────
create table public.devices (
  device_id     uuid primary key default gen_random_uuid(),
  zone_id       uuid not null references public.zones(zone_id) on delete cascade,
  device_name   varchar(100) not null,
  device_type   varchar(20) not null default 'meter' check (device_type in ('ESP32','meter','sensor')),
  serial_number varchar(50) not null unique,
  api_key       uuid not null default gen_random_uuid(), -- secret token the meter uses to send readings
  status        varchar(10) not null default 'active' check (status in ('active','inactive')),
  installed_at  timestamptz not null default now(),
  last_seen_at  timestamptz
);

-- ── Table 4: ENERGY READING ──────────────────────────────────
create table public.energy_readings (
  reading_id   bigint generated always as identity primary key,
  device_id    uuid not null references public.devices(device_id) on delete cascade,
  "timestamp"  timestamptz not null default now(),
  voltage      numeric(7,2) not null,   -- V
  current      numeric(7,3) not null,   -- A
  power        numeric(10,2) not null,  -- W
  energy_kwh   numeric(12,4) not null,  -- kWh
  power_factor numeric(4,3)
);
create index energy_readings_device_time on public.energy_readings (device_id, "timestamp" desc);

-- ── Table 5: ALERT ───────────────────────────────────────────
create table public.alerts (
  alert_id        uuid primary key default gen_random_uuid(),
  device_id       uuid not null references public.devices(device_id) on delete cascade,
  reading_id      bigint references public.energy_readings(reading_id) on delete set null,
  alert_type      varchar(20) not null check (alert_type in ('overload','anomaly','voltage_high','voltage_low')),
  severity        varchar(10) not null check (severity in ('low','medium','high')),
  message         text not null,
  alert_time      timestamptz not null default now(),
  is_acknowledged boolean not null default false
);
create index alerts_device_time on public.alerts (device_id, alert_time desc);

-- ── Auto-create a profile row when someone registers ─────────
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''), new.email);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── Row Level Security: each user only sees their own data ───
alter table public.profiles        enable row level security;
alter table public.zones           enable row level security;
alter table public.devices         enable row level security;
alter table public.energy_readings enable row level security;
alter table public.alerts          enable row level security;

create policy "own profile" on public.profiles
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own zones" on public.zones
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own devices" on public.devices
  for all using (exists (select 1 from public.zones z where z.zone_id = devices.zone_id and z.user_id = auth.uid()))
  with check  (exists (select 1 from public.zones z where z.zone_id = devices.zone_id and z.user_id = auth.uid()));

create policy "own readings (read)" on public.energy_readings
  for select using (exists (
    select 1 from public.devices d join public.zones z on z.zone_id = d.zone_id
    where d.device_id = energy_readings.device_id and z.user_id = auth.uid()));

create policy "own alerts (read)" on public.alerts
  for select using (exists (
    select 1 from public.devices d join public.zones z on z.zone_id = d.zone_id
    where d.device_id = alerts.device_id and z.user_id = auth.uid()));

create policy "own alerts (acknowledge)" on public.alerts
  for update using (exists (
    select 1 from public.devices d join public.zones z on z.zone_id = d.zone_id
    where d.device_id = alerts.device_id and z.user_id = auth.uid()));

-- ── Meter → cloud: the only way readings get in ──────────────
-- The meter (or simulator) calls POST /rest/v1/rpc/ingest_reading with its
-- serial number + api_key. Wrong key = rejected. Also raises edge alerts
-- (over/under voltage, overcurrent) using the thresholds from the app.
create function public.ingest_reading(
  p_serial text, p_api_key uuid,
  p_voltage numeric, p_current numeric, p_power numeric, p_energy_kwh numeric,
  p_power_factor numeric default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_device  public.devices%rowtype;
  v_reading bigint;
begin
  select * into v_device from public.devices
   where serial_number = p_serial and api_key = p_api_key and status = 'active';
  if not found then
    raise exception 'unknown device or wrong api key' using errcode = '28000';
  end if;

  insert into public.energy_readings (device_id, voltage, current, power, energy_kwh, power_factor)
  values (v_device.device_id, p_voltage, p_current, p_power, p_energy_kwh, p_power_factor)
  returning reading_id into v_reading;

  update public.devices set last_seen_at = now() where device_id = v_device.device_id;

  if p_voltage > 250 then
    insert into public.alerts (device_id, reading_id, alert_type, severity, message)
    values (v_device.device_id, v_reading, 'voltage_high', 'high',
            format('Voltage %s V is above the 250 V limit', p_voltage));
  elsif p_voltage < 210 then
    insert into public.alerts (device_id, reading_id, alert_type, severity, message)
    values (v_device.device_id, v_reading, 'voltage_low', 'high',
            format('Voltage %s V is below the 210 V limit', p_voltage));
  end if;

  if p_current > 20 then
    insert into public.alerts (device_id, reading_id, alert_type, severity, message)
    values (v_device.device_id, v_reading, 'overload', 'medium',
            format('Current %s A is above the 20 A limit', p_current));
  end if;

  return v_reading;
end $$;

revoke all on function public.ingest_reading from public;
grant execute on function public.ingest_reading to anon, authenticated;

-- ── Realtime: app screens update live when new rows arrive ───
alter publication supabase_realtime add table public.energy_readings, public.alerts, public.zones, public.devices;
