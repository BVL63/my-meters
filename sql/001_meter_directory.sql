-- Мои счётчики: этап 1 — справочник приборов.
-- Без удаления и переноса существующих показаний.
-- Выполнить один раз в Supabase SQL Editor.
begin;

alter table public.meters
  add column if not exists installed_on date,
  add column if not exists removed_on date,
  add column if not exists initial_reading numeric(14,3),
  add column if not exists initial_reading_approximate boolean not null default false,
  add column if not exists replacement_of bigint references public.meters(id) on delete restrict,
  add column if not exists notes text;

-- active уже существует: false означает архивный/снятый прибор.
-- Проверки добавляем без изменения ранее созданных строк.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'meters_initial_reading_nonnegative') then
    alter table public.meters add constraint meters_initial_reading_nonnegative
      check (initial_reading is null or initial_reading >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'meters_dates_order') then
    alter table public.meters add constraint meters_dates_order
      check (removed_on is null or installed_on is null or removed_on >= installed_on);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'meters_no_self_replacement') then
    alter table public.meters add constraint meters_no_self_replacement
      check (replacement_of is null or replacement_of <> id);
  end if;
end $$;

create index if not exists meters_user_resource_idx
  on public.meters (user_id, resource, active);
create index if not exists readings_meter_period_idx
  on public.readings (meter_id, period);

commit;

-- Контроль: все существующие приборы и показания должны остаться на месте.
select (select count(*) from public.meters) as meters_total,
       (select count(*) from public.readings) as readings_total;
