-- Identify users by email or name: skills running where `git` isn't available
-- (e.g. Claude desktop / claude.ai) ask the user instead.

alter table public.tuningfork_events rename column user_email to user_identity;
alter table public.tuningfork_events drop constraint tuningfork_events_user_email_check;
alter table public.tuningfork_events add constraint tuningfork_events_user_identity_check
  check (char_length(btrim(user_identity)) between 1 and 200);

create index tuningfork_events_user_created_idx
  on public.tuningfork_events (user_identity, created_at desc);

-- Recreate the view so its column is also called user_identity.
drop view public.tuningfork_runs;

create view public.tuningfork_runs
with (security_invoker = true) as
select
  r.run_id,
  r.created_at,
  r.skill_name,
  r.skill_version,
  r.user_identity,
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
