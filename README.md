# Tuning Fork

**Find out which AI skills ring true and which are off-key.**

Tuning Fork collects a thumbs up or down every time someone uses an AI skill, in one shared place, so skill authors can see where their skill falls short.

Pick what describes you:

- [I use skills](#i-use-skills) (2 minutes)
- [I build skills](#i-build-skills) (5 minutes)
- [I review the results](#i-review-the-results)

---

## I use skills

### Step 1: Add Tuning Fork to your AI tool

Copy the line for the tool you use.

**GitHub Copilot CLI:** paste this into your terminal (not inside Copilot):

```text
copilot mcp add --transport http tuningfork https://ziwygmfxsynuccngnehe.supabase.co/functions/v1/tuningfork
```

**Claude Code:** paste this into your terminal:

```text
claude mcp add --transport http tuningfork https://ziwygmfxsynuccngnehe.supabase.co/functions/v1/tuningfork
```

**Claude desktop app or claude.ai:**

1. Open **Settings → Connectors → Add custom connector**.
2. Name: `Tuning Fork`
3. URL: `https://ziwygmfxsynuccngnehe.supabase.co/functions/v1/tuningfork`
4. Click **Add**.

### Step 2: Check it worked

Start a new chat in your AI tool and paste:

```text
List the tools from the tuningfork MCP server.
```

You should see `log_run`, `log_rating` and `connect_skill`.

That's it. When you use a skill that's connected to Tuning Fork, it will tell you it's logging and ask for a thumbs up or down at the end. Say **"don't log"** at the start of any chat to opt out.

---

## I build skills

### Step 1: Add Tuning Fork to your AI tool

Same as [Step 1 above](#step-1-add-tuning-fork-to-your-ai-tool).

### Step 2: Connect your skill

Open a terminal **in your skill's folder** (the one that contains `SKILL.md`), start Copilot CLI or Claude Code, and paste:

```text
Connect the skill in this folder to Tuning Fork. Read the skill's name from the "name:" line at the top of SKILL.md. Call the tuningfork connect_skill tool with that name. Add the text it returns to the very end of SKILL.md without changing anything else. Then show me exactly what you added.
```

### Step 3: Publish the change

Paste:

```text
Commit SKILL.md with the message "Connect skill to Tuning Fork" and push it.
```

### Step 4: Try it once

Use your skill as normal. At the end it should ask "Did this help? Thumbs up or down, and what was missing?" Answer it. Your run is now in Tuning Fork.

### No AI tool handy? Add it by hand

Copy the block below to the very end of your `SKILL.md`. Replace `your-skill-name` (it appears twice) with the `name:` from the top of your `SKILL.md`.

````markdown
## Tuning Fork feedback

This skill reports how well it worked to Tuning Fork (the `tuningfork` MCP server).
If the `tuningfork` tools aren't available, skip this whole section silently.

1. Before you start, tell the user in one line: "To improve this skill, I'll log your question, my answer and your rating to the skill owner. Say 'don't log' to opt out." If they opt out, skip steps 2 and 4 but still ask step 3.
2. Right after giving your answer, get the user's email by running `git config user.email`, then call `log_run` with:
   - skill_name: "your-skill-name"
   - skill_version: "1.0.0"
   - user_email: that email
   - question: the user's request, in their words
   - answer: your final answer text
   - metadata: (optional) any structured details worth reviewing, as a JSON object
   Remember the run_id it returns.
3. End your answer with exactly one question: "Did this help? Thumbs up or down, and what was missing?"
4. When the user answers (even several messages later), call `log_rating` with the run_id, skill_name "your-skill-name", user_email, rating "up" or "down", comment (their words, if any) and followup_count (how many follow-up questions they asked).
5. If a Tuning Fork call fails, mention it in one line and carry on. Never retry more than once.
````

---

## I review the results

Only the owner of the Supabase project can read results. Skill authors: ask the owner for your skill's results.

1. Open the [SQL Editor](https://supabase.com/dashboard/project/ziwygmfxsynuccngnehe/sql/new).
2. Paste this, replace `your-skill-name`, and click **Run**:

```sql
select created_at, user_email, rating, comment, question, answer
from tuningfork_runs
where skill_name = 'your-skill-name'
order by created_at desc;
```

To see only the misses, add `and rating = 'down'` before `order by`.

To see how every skill is doing:

```sql
select skill_name,
       count(*)                                   as runs,
       count(*) filter (where rating = 'up')      as thumbs_up,
       count(*) filter (where rating = 'down')    as thumbs_down,
       count(*) filter (where rating is null)     as not_rated
from tuningfork_runs
group by skill_name
order by runs desc;
```

---

## Good to know

- **What's stored:** the skill's name, your email (from `git config user.email`), your question, the skill's answer, your rating and comment.
- **Where:** a Supabase database in Singapore, outside any company tenant. Don't use Tuning Fork with skills that handle confidential or customer data.
- **Who can read it:** only the Supabase project owner. Anyone with the URL can send events, but nobody can read them through it.
- **Limits:** each email can send 30 events a minute; long questions and answers are rejected.

## How it works

```text
Your AI tool ──log_run / log_rating──► "tuningfork" Edge Function ──► tuningfork_events table
                                       (checks input, holds the key)   (closed to the public)
```

| File | What it is |
|---|---|
| `supabase/functions/tuningfork/index.ts` | The MCP server and its three tools |
| `supabase/migrations/20261007000000_tuningfork_events.sql` | The table, its checks and the `tuningfork_runs` review view |

To run your own copy (needs Node.js):

```text
npx supabase login
npx supabase link --project-ref YOUR-PROJECT-REF
npx supabase db push
npx supabase functions deploy tuningfork --use-api
```
