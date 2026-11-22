-- Выполнить один раз в SQL Editor проекта Supabase
ALTER TABLE public.meters ADD COLUMN IF NOT EXISTS verification_date date;
-- Дата поверки для ХВС и ГВС (по сведениям Госуслуги Дом)
UPDATE public.meters SET verification_date = DATE '2028-09-12' WHERE serial_number IN ('220083027','220083024');
-- Для электросчётчика дату поверки ввести вручную после уточнения.
