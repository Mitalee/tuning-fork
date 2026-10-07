-- Public, aggregate-only skill leaderboard. The underlying event data remains private.
-- Bayesian scoring uses the platform-wide approval rate with a prior strength of 10 ratings.

create view public.tuningfork_skill_leaderboard
with (security_barrier = true) as
with latest_ratings as (
  select
    e.run_id,
    e.rating,
    row_number() over (
      partition by e.run_id
      order by e.created_at desc, e.id desc
    ) as recency
  from public.tuningfork_events e
  where e.event_type = 'rating'
),
skill_totals as (
  select
    r.skill_name,
    count(*)::bigint as total_runs,
    count(l.rating)::bigint as rated_runs,
    count(*) filter (where l.rating = 'up')::bigint as upvotes,
    count(*) filter (where l.rating = 'down')::bigint as downvotes,
    max(r.created_at) as last_run_at
  from public.tuningfork_events r
  left join latest_ratings l
    on l.run_id = r.run_id and l.recency = 1
  where r.event_type = 'run'
  group by r.skill_name
),
global_stats as (
  select
    coalesce(
      sum(s.upvotes)::numeric / nullif(sum(s.rated_runs), 0),
      0.5
    ) as approval_rate
  from skill_totals s
),
scored as (
  select
    s.*,
    round(100.0 * s.upvotes / nullif(s.rated_runs, 0), 2) as approval_rate,
    round(100.0 * s.rated_runs / nullif(s.total_runs, 0), 2) as rating_rate,
    case
      when s.rated_runs = 0 then null
      else round(
        100.0 * (s.upvotes + 10.0 * g.approval_rate) / (s.rated_runs + 10.0),
        2
      )
    end as bayesian_score
  from skill_totals s
  cross join global_stats g
)
select
  row_number() over (
    order by
      s.bayesian_score desc nulls last,
      s.rated_runs desc,
      s.total_runs desc,
      s.skill_name
  )::bigint as rank,
  s.skill_name,
  s.bayesian_score,
  s.approval_rate,
  s.rating_rate,
  s.total_runs,
  s.rated_runs,
  s.upvotes,
  s.downvotes,
  s.last_run_at
from scored s;

comment on view public.tuningfork_skill_leaderboard is
  'Public aggregate skill rankings. Bayesian score uses the global approval rate and a 10-rating prior.';

revoke all on public.tuningfork_skill_leaderboard from public, anon, authenticated;
grant select on public.tuningfork_skill_leaderboard to anon, authenticated;
