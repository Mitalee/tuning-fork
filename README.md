# Tuning Fork

Find out which AI skills ring true and which are off-key.

Tuning Fork is a shared eval collector for AI agent skills (Copilot CLI, Claude and other MCP clients). Any skill can report each answer it gives, and the user's thumbs up or down, to one shared table. Skill owners then filter that table to see where their skill falls short.

It runs as a public MCP server on a Supabase Edge Function, so nobody has to install anything except the server URL.

```text
PM's agent ──log_run / log_rating──► Edge Function "tuningfork" ──► tuningfork_events table
                                     (validates, holds the key)      (closed to the public API)
```

## MCP server URL

```text
https://ziwygmfxsynuccngnehe.supabase.co/functions/v1/tuningfork
```

## For skill users

Add the URL above as an MCP server once:

- **Copilot CLI:** run `/mcp add`, choose **HTTP**, name it `tuningfork` and paste the URL.
- **Claude:** Settings → Connectors → Add custom connector, and paste the URL.

That's it. Skills connected to Tuning Fork will tell you they log your question, the answer and your rating, and you can say "don't log" to opt out. If Tuning Fork isn't added, those skills simply skip logging.

## For skill authors

1. Add the MCP server as above.
2. Open your skill folder in your agent and say: **"Connect my skill to Tuning Fork."**
   The agent calls `connect_skill`, which returns a short block to append to your `SKILL.md`.
3. Push your skill.

From then on, every run of your skill is logged under your skill's name.

## Tools

| Tool | When the agent calls it | What it stores |
|---|---|---|
| `log_run` | Right after the skill answers | Skill name and version, user email, question, answer, optional `metadata`; returns a `run_id` |
| `log_rating` | When the user gives thumbs up or down | `run_id`, rating, comment ("what was missing"), follow-up count |
| `connect_skill` | Once, by a skill author | Nothing; returns the `SKILL.md` block |

Inputs are size-limited and validated. A rating must reference an existing run of the same skill. Each email can send at most 30 events per minute.

## Reviewing results

In the Supabase dashboard, open the Table Editor and choose the **`tuningfork_runs`** view. It shows one row per run with its latest rating. Filter by `skill_name`, `rating = down` or date.

The raw events (one `run` row plus `rating` rows per run) are in **`tuningfork_events`**.

## Privacy

- Data is stored in a Supabase project in Southeast Asia (Singapore), outside any corporate tenant. Don't use Tuning Fork with skills that handle confidential or customer data.
- The user's identity is the email from `git config user.email`, as reported by their agent. It isn't verified.
- Anyone with the URL can send events. Nobody can read events through the public API; only the project owner can, from the dashboard.

## Repository layout

```text
supabase/
├─ config.toml                                   verify_jwt = false for the public MCP endpoint
├─ migrations/20261007000000_tuningfork_events.sql   table, checks, indexes, RLS, review view
└─ functions/tuningfork/
   ├─ index.ts                                   the MCP server
   └─ deno.json                                  dependencies
```

## Deploying your own copy

Needs Node.js. Docker isn't required.

```bash
npx supabase login
npx supabase link --project-ref <your-project-ref>
npx supabase db push
npx supabase functions deploy tuningfork --use-api
```
