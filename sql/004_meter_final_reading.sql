alter table public.meters add column if not exists final_reading numeric(14,3) check (final_reading >= 0);
update public.meters m set final_reading=e.old_final_reading
from public.meter_replacement_events e
where e.old_meter_id=m.id and e.user_id=m.user_id and e.old_final_reading is not null and m.final_reading is null;