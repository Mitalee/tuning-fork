-- Tuning Fork: one shared table of eval events for every skill.
-- Rows are written only by the "tuningfork" Edge Function (service role).
-- The public anon/authenticated roles get no access at all.

create table public.tuningfork_events (
  id             bigint generated always as identity primary key,
  created_at     timestamptz not null default now(),
  event_type     text        not null check (event_type in ('run', 'rating')),
  run_id         uuid        not null,
  skill_name     text        not null check (char_length(skill_name) between 1 and 100),
  skill_version  text                 check (char_length(skill_version) <= 50),
  user_email     text        not null check (char_length(user_email) <= 200 and user_email like '%_@_%'),

  -- run events
  question       text                 check (char_length(question) <= 4000),
  answer         text                 check (char_length(answer) <= 20000),

  -- rating events
  rating         text                 check (rating in ('up', 'down')),
  comment        text                 check (char_length(comment) <= 2000),
  followup_count int                  check (followup_count between 0 and 100),

  -- skill-specific extras, e.g. persona, jtbd, map_json for customer-journey-map
  metadata       jsonb       not null default '{}'::jsonb
                                      check (jsonb_typeof(metadata) = 'object' and pg_column_size(metadata) <= 100000),

  constraint tuningfork_event_shape check (
    (event_type = 'run'    and question is not null and answer is not null
                           and rating is null and comment is null and followup_count is null)
    or
    (event_type = 'rating' and rating is not null and question is null and answer is null)
  )
);

comment on table public.tuningfork_events is
  'Tuning Fork eval events. One "run" row per skill answer, plus "rating" rows sharing its run_id.';

-- At most one run row per run_id; ratings may be re-sent (latest wins in the view).
create unique index tuningfork_events_one_run_per_id
  on public.tuningfork_events (run_id) where event_type = 'run';

create index tuningfork_events_run_id_idx       on public.tuningfork_events (run_id);
create index tuningfork_events_skill_created_idx on public.tuningfork_events (skill_name, created_at desc);
create index tuningfork_events_created_idx       on public.tuningfork_events (created_at desc);

-- Lock the table down: RLS on, no policies, no grants to API roles.
alter table public.tuningfork_events enable row level security;
revoke all on public.tuningfork_events from anon, authenticated;

-- Review view: one row per run, with its latest rating (if any).
create view public.tuningfork_runs
with (security_invoker = true) as
select
  r.run_id,
  r.created_at,
  r.skill_name,
  r.skill_version,
  r.user_email,
  r.question,
  r.answer,
  r.metadata,
  l.rating,
  l.comment,
  l.followup_count,
  l.created_at as rated_at
from public.tuningfork_events r
left join lateral (
  select e.rating, e.comment, e.followup_count, e.created_at
  from public.tuningfork_events e
  where e.run_id = r.run_id and e.event_type = 'rating'
  order by e.created_at desc
  limit 1
) l on true
where r.event_type = 'run';

revoke all on public.tuningfork_runs from anon, authenticated;
