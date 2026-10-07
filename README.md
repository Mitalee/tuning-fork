# Tuning Fork

**Find out how well your AI skill actually works.**

Connect your skill to Tuning Fork and, every time someone uses it, the skill asks them to rate the answer: **1** for 👍 or **0** for 👎, plus an optional comment. Each run and rating is logged so you can see where your skill falls short.

Setup takes about 5 minutes.

---

## Step 1: Add Tuning Fork to your AI tool

**Easiest:** inside GitHub Copilot CLI or Claude Code, paste:

```text
Install Tuning Fork by following the instructions at https://github.com/Mitalee/tuning-fork
```

Approve the install command when asked, then restart your AI tool.

**Or** run one line in your terminal (not inside your AI tool). It adds Tuning Fork to GitHub Copilot CLI and/or Claude Code, whichever you have, and stops them asking for approval every time your skill logs.

Windows (PowerShell):

```text
irm https://raw.githubusercontent.com/Mitalee/tuning-fork/main/install.ps1 | iex
```

Mac or Linux:

```text
curl -fsSL https://raw.githubusercontent.com/Mitalee/tuning-fork/main/install.sh | sh
```

Then open a new terminal window. On Windows, start Copilot CLI from PowerShell (not Command Prompt).

To check it worked, start Copilot CLI or Claude Code and paste:

```text
List the tools from the tuningfork MCP server.
```

You should see `log_run`, `log_rating` and `connect_skill`.

## Step 2: Connect your skill

In Copilot CLI or Claude Code, say (with your skill's name):

```text
Connect my skill customer-journey-map to Tuning Fork
```

It finds the skill, adds a short "Tuning Fork feedback" section to the end of its `SKILL.md`, and shows you what it added. If it can't find the skill, it asks you where it is.

## Step 3: Publish the change

If your skill lives in a GitHub repo, say:

```text
Commit that SKILL.md change with the message "Connect skill to Tuning Fork" and push it.
```

## Step 4: Try it once

Use your skill as normal. At the end it should say "Tuning Fork - Rate this: 1 = 👍, 0 = 👎 (add a comment after the number if you like)". Reply with `1` or `0`.

## Step 5: Tell your skill's users

Your skill only logs for people who have Tuning Fork in their AI tool. Add this line to your skill's README:

````markdown
**Help improve this skill:** tell your AI tool `Install Tuning Fork by following the instructions at https://github.com/Mitalee/tuning-fork`, then rate each answer 1 (👍) or 0 (👎).
````

Don't connect skills that handle confidential or customer data: the questions and answers are sent to Tuning Fork.

---

## Skill leaderboard

The public leaderboard ranks skills by Bayesian-adjusted approval. This prevents a skill with one positive rating from automatically outranking a well-tested skill with many positive ratings.

The adjusted score starts every skill with 10 ratings at the platform-wide approval rate:

```text
(upvotes + 10 * global approval rate) / (ratings + 10)
```

Only aggregate statistics are public. Questions, answers and user identities remain inaccessible.

The Supabase Edge Function exposes aggregate leaderboard data as JSON:

```text
https://ziwygmfxsynuccngnehe.supabase.co/functions/v1/leaderboard
```

The public page is in `docs/index.html`, ready for GitHub Pages. Deploy the API with:

```text
supabase db push
supabase functions deploy leaderboard
```

Then enable GitHub Pages for the repository using the `main` branch and `/docs` folder. The page will be:

```text
https://mitalee.github.io/tuning-fork/
```

---

## Prefer to do it by hand?

**Connect your skill without an AI tool**

Copy the block below to the very end of your `SKILL.md`. Replace `your-skill-name` (it appears twice) with the `name:` from the top of your `SKILL.md`.

````markdown
## Tuning Fork feedback

This skill reports how well it worked to Tuning Fork (the `tuningfork` MCP server).
If the `tuningfork` tools aren't available, skip this whole section silently.

1. Before you start, tell the user in one line: "To improve this skill, I'll log your question, my answer and your rating to the skill owner. Say 'don't log' to opt out." If they opt out, skip steps 2 and 4 but still ask step 3.
2. Right after giving your answer, work out who the user is: run `git config user.email`. If you can't run commands or it returns nothing, ask the user once: "What name or email should I log this under?" and reuse their answer for the rest of the chat. Then call `log_run` with:
   - skill_name: "your-skill-name"
   - skill_version: "1.0.0"
   - user_identity: that email or name
   - question: the user's request, in their words
   - answer: your final answer text
   - metadata: (optional) any structured details worth reviewing, as a JSON object
   Remember the run_id it returns.
3. End your answer with exactly this line, on its own: "Tuning Fork - Rate this: 1 = 👍, 0 = 👎 (add a comment after the number if you like)"
4. When the user replies with a message that starts with 1 or 0 (even several messages later), treat it as their rating: 1 means "up", 0 means "down", and any words after the number are their comment. Then call `log_rating` with the run_id, skill_name "your-skill-name", user_identity, rating "up" or "down", comment (their words, if any) and followup_count (how many follow-up questions they asked).
5. If a Tuning Fork call fails, mention it in one line and carry on. Never retry more than once.
````
