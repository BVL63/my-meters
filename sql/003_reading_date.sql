alter table public.readings add column if not exists reading_date date;
comment on column public.readings.reading_date is 'Actual date the meter reading was taken; may differ from billing period and entry timestamp';
