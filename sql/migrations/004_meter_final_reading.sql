ALTER TABLE public.meters ADD COLUMN IF NOT EXISTS final_reading numeric(14,3) CHECK (final_reading >= 0);
UPDATE public.meters m SET final_reading=e.old_final_reading FROM public.meter_replacement_events e WHERE e.old_meter_id=m.id AND e.user_id=m.user_id AND e.old_final_reading IS NOT NULL AND m.final_reading IS NULL;
