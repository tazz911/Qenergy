-- EnergyIQ — part 2: user settings + dashboard calculations.
-- Run AFTER schema.sql. Safe to run more than once (keeps all data).
-- Supabase → SQL Editor → New query → paste → Run.

-- ── User settings (Settings screen) ──────────────────────────
alter table public.profiles
  add column if not exists voltage_min        numeric(6,1) not null default 210,
  add column if not exists voltage_max        numeric(6,1) not null default 250,
  add column if not exists current_max        numeric(6,1) not null default 20,
  add column if not exists push_notifications boolean      not null default true,
  add column if not exists anomaly_alerts     boolean      not null default true,
  add column if not exists email_reports      boolean      not null default false;

-- energy_kwh in each reading = energy used since that device's previous reading,
-- so usage for any period = sum(energy_kwh).

-- ── kWh per zone between two times (Home, Analytics) ─────────
-- "security invoker" (the default) → Row Level Security still applies.
create or replace function public.zone_usage(p_from timestamptz, p_to timestamptz)
returns table (zone_id uuid, kwh numeric)
language sql stable set search_path = public as $$
  select d.zone_id, coalesce(sum(r.energy_kwh), 0)
  from public.devices d
  left join public.energy_readings r
    on r.device_id = d.device_id and r."timestamp" >= p_from and r."timestamp" < p_to
  group by d.zone_id;
$$;

-- ── Usage grouped by hour or day (charts) ────────────────────
create or replace function public.usage_buckets(
  p_from timestamptz, p_to timestamptz,
  p_bucket text default 'hour',      -- 'hour' or 'day'
  p_zone uuid default null           -- null = all zones
) returns table (bucket timestamptz, kwh numeric, avg_voltage numeric, max_power numeric)
language sql stable set search_path = public as $$
  select date_trunc(p_bucket, r."timestamp" at time zone 'Asia/Muscat') at time zone 'Asia/Muscat',
         sum(r.energy_kwh), avg(r.voltage), max(r.power)
  from public.energy_readings r
  join public.devices d on d.device_id = r.device_id
  where r."timestamp" >= p_from and r."timestamp" < p_to
    and (p_zone is null or d.zone_id = p_zone)
  group by 1
  order by 1;
$$;

-- ── Newest reading of each device seen in the last 10 minutes (live values) ──
create or replace function public.latest_readings()
returns setof public.energy_readings
language sql stable set search_path = public as $$
  select distinct on (device_id) *
  from public.energy_readings
  where "timestamp" > now() - interval '10 minutes'
  order by device_id, "timestamp" desc;
$$;

-- ── Meter → cloud, now using each owner's own limits from Settings ──
create or replace function public.ingest_reading(
  p_serial text, p_api_key uuid,
  p_voltage numeric, p_current numeric, p_power numeric, p_energy_kwh numeric,
  p_power_factor numeric default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_device  public.devices%rowtype;
  v_owner   public.profiles%rowtype;
  v_reading bigint;
  v_type    text;
  v_sev     text;
  v_msg     text;
begin
  select * into v_device from public.devices
   where serial_number = p_serial and api_key = p_api_key and status = 'active';
  if not found then
    raise exception 'unknown device or wrong api key' using errcode = '28000';
  end if;

  select p.* into v_owner from public.profiles p
    join public.zones z on z.user_id = p.user_id
   where z.zone_id = v_device.zone_id;

  insert into public.energy_readings (device_id, voltage, current, power, energy_kwh, power_factor)
  values (v_device.device_id, p_voltage, p_current, p_power, p_energy_kwh, p_power_factor)
  returning reading_id into v_reading;

  update public.devices set last_seen_at = now() where device_id = v_device.device_id;

  -- Edge alerts. Skips repeats: no new alert if the same problem is already
  -- open (not acknowledged) for this device in the last 10 minutes.
  if p_voltage > v_owner.voltage_max then
    v_type := 'voltage_high'; v_sev := 'high';
    v_msg  := format('Voltage %s V is above the %s V limit', p_voltage, v_owner.voltage_max);
  elsif p_voltage < v_owner.voltage_min then
    v_type := 'voltage_low'; v_sev := 'high';
    v_msg  := format('Voltage %s V is below the %s V limit', p_voltage, v_owner.voltage_min);
  end if;
  if v_type is not null then
    insert into public.alerts (device_id, reading_id, alert_type, severity, message)
    select v_device.device_id, v_reading, v_type, v_sev, v_msg
    where not exists (select 1 from public.alerts a
                      where a.device_id = v_device.device_id and a.alert_type = v_type
                        and not a.is_acknowledged and a.alert_time > now() - interval '10 minutes');
  end if;

  if p_current > v_owner.current_max then
    insert into public.alerts (device_id, reading_id, alert_type, severity, message)
    select v_device.device_id, v_reading, 'overload', 'medium',
           format('Current %s A is above the %s A limit', p_current, v_owner.current_max)
    where not exists (select 1 from public.alerts a
                      where a.device_id = v_device.device_id and a.alert_type = 'overload'
                        and not a.is_acknowledged and a.alert_time > now() - interval '10 minutes');
  end if;

  return v_reading;
end $$;

revoke all on function public.ingest_reading from public;
grant execute on function public.ingest_reading to anon, authenticated;
