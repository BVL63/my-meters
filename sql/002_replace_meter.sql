-- Этап 2. Атомарная замена прибора учёта.
-- Запускайте в Supabase SQL Editor. Существующие записи не меняются при установке функции.
create or replace function public.replace_meter(
  p_old_meter_id bigint,
  p_replaced_on date,
  p_new_name text,
  p_new_serial text,
  p_new_initial numeric,
  p_initial_approximate boolean default false,
  p_old_final numeric default null,
  p_notes text default null
) returns bigint
language plpgsql security invoker set search_path = public
as $$
declare
  old_m public.meters%rowtype;
  new_id bigint;
begin
  select * into old_m from public.meters
    where id=p_old_meter_id and user_id=(select auth.uid()) and active=true
    for update;
  if not found then raise exception 'Действующий счётчик не найден'; end if;
  if p_replaced_on is null then raise exception 'Укажите точную дату замены'; end if;
  if old_m.installed_on is not null and p_replaced_on<old_m.installed_on then
    raise exception 'Дата замены раньше установки старого счётчика';
  end if;
  if nullif(trim(p_new_name),'') is null then raise exception 'Укажите название нового счётчика'; end if;
  if p_new_initial is null or p_new_initial<0 then raise exception 'Укажите начальные показания'; end if;
  if p_old_final is not null and p_old_final<0 then raise exception 'Неверные конечные показания'; end if;

  -- Перенос месячных записей только с месяца замены, в пределах одного ресурса.
  -- При замене внутри месяца месячное показание относится новому прибору.
  insert into public.meters
    (user_id,name,resource,serial_number,location,tariff_count,active,
     installed_on,initial_reading,initial_reading_approximate,replacement_of,notes)
  values
    ((select auth.uid()),trim(p_new_name),old_m.resource,nullif(trim(p_new_serial),''),
     old_m.location,old_m.tariff_count,true,p_replaced_on,p_new_initial,
     coalesce(p_initial_approximate,false),old_m.id,nullif(trim(p_notes),''))
  returning id into new_id;

  update public.readings
     set meter_id=new_id
   where user_id=(select auth.uid())
     and meter_id=old_m.id
     and period>=date_trunc('month',p_replaced_on)::date;

  update public.meters
     set active=false,removed_on=p_replaced_on
   where id=old_m.id and user_id=(select auth.uid());

  -- Значение на момент снятия хранится отдельно от месячных показаний.
  insert into public.meter_replacement_events
    (user_id,old_meter_id,new_meter_id,replaced_on,old_final_reading,new_initial_reading,notes)
  values ((select auth.uid()),old_m.id,new_id,p_replaced_on,p_old_final,p_new_initial,p_notes);

  return new_id;
end $$;

create table if not exists public.meter_replacement_events (
 id bigint generated always as identity primary key,
 user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 old_meter_id bigint not null references public.meters(id),
 new_meter_id bigint not null unique references public.meters(id),
 replaced_on date not null,
 old_final_reading numeric(14,3) check (old_final_reading>=0),
 new_initial_reading numeric(14,3) not null check (new_initial_reading>=0),
 notes text,
 created_at timestamptz not null default now()
);
alter table public.meter_replacement_events enable row level security;
drop policy if exists "Users manage own replacements" on public.meter_replacement_events;
create policy "Users manage own replacements" on public.meter_replacement_events
for all to authenticated using (user_id=(select auth.uid()))
with check (user_id=(select auth.uid()));
grant select,insert,update,delete on public.meter_replacement_events to authenticated;
grant usage,select on sequence public.meter_replacement_events_id_seq to authenticated;
revoke all on function public.replace_meter(bigint,date,text,text,numeric,boolean,numeric,text) from public;
grant execute on function public.replace_meter(bigint,date,text,text,numeric,boolean,numeric,text) to authenticated;
