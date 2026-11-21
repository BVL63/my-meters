-- Ensure the readings date field exists before the application selects it.
ALTER TABLE public.readings
  ADD COLUMN IF NOT EXISTS reading_date date;

COMMENT ON COLUMN public.readings.reading_date IS
  'Actual date when the reading was taken; distinct from billing period.';
