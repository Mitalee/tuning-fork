// Tuning Fork: a public MCP server that collects eval events from any skill
// into the shared tuningfork_events table.
//
// Anyone with the URL can call it. The secret key never leaves this function;
// the table itself is closed to the public API roles.

import "@supabase/functions-js/edge-runtime.d.ts";
import { type SupabaseContext, withSupabase } from "@supabase/server";
import { createMcpHandler, McpServer } from "@modelcontextprotocol/server";
import { z } from "zod";

const TABLE = "tuningfork_events";
const MAX_EVENTS_PER_USER_PER_MINUTE = 30;

const skillName = z.string().trim().min(1).max(100)
  .describe("The skill's name, exactly as in its SKILL.md, e.g. customer-journey-map");
const userIdentity = z.string().trim().min(1).max(200)
  .describe(
    "Who the user is: their email from `git config user.email`. If you can't run commands or it's empty, " +
      "the name or email the user gave when asked.",
  );

const text = (t: string) => ({ content: [{ type: "text" as const, text: t }] });
const fail = (t: string) => ({ ...text(t), isError: true });

function snippetFor(name: string, version: string) {
  return `## Tuning Fork feedback

This skill reports how well it worked to Tuning Fork (the \`tuningfork\` MCP server).
If the \`tuningfork\` tools aren't available, skip this whole section silently.

1. Before you start, tell the user in one line: "To improve this skill, I'll log your question, my answer and your rating to the skill owner. Say 'don't log' to opt out." If they opt out, skip steps 2 and 4 but still ask step 3.
2. Right after giving your answer, work out who the user is: run \`git config user.email\`. If you can't run commands or it returns nothing, ask the user once: "What name or email should I log this under?" and reuse their answer for the rest of the chat. Then call \`log_run\` with:
   - skill_name: "${name}"
   - skill_version: "${version}"
   - user_identity: that email or name
   - question: the user's request, in their words
   - answer: your final answer text
   - metadata: (optional) any structured details worth reviewing, as a JSON object
   Remember the run_id it returns.
3. End your answer with exactly this line, on its own: "Rate this: 1 = 👍, 0 = 👎 (add a comment after the number if you like)"
4. When the user replies with a message that starts with 1 or 0 (even several messages later), treat it as their rating: 1 means "up", 0 means "down", and any words after the number are their comment. Then call \`log_rating\` with the run_id, skill_name "${name}", user_identity, rating "up" or "down", comment (their words, if any) and followup_count (how many follow-up questions they asked).
5. If a Tuning Fork call fails, mention it in one line and carry on. Never retry more than once.`;
}

function buildServer(db: SupabaseContext["supabaseAdmin"]) {
  const server = new McpServer(
    { name: "tuningfork", version: "1.0.0" },
    {
      instructions:
        "Tuning Fork records how well AI skills work. Call log_run after a skill gives its answer, " +
        "then log_rating when the user rates it (1 = up, 0 = down). Skill authors call connect_skill " +
        "to get the block to paste into their SKILL.md.",
    },
  );

  async function overRateLimit(user: string) {
    const since = new Date(Date.now() - 60_000).toISOString();
    const { count, error } = await db.from(TABLE)
      .select("id", { count: "exact", head: true })
      .eq("user_identity", user)
      .gte("created_at", since);
    return !error && (count ?? 0) >= MAX_EVENTS_PER_USER_PER_MINUTE;
  }

  server.registerTool("log_run", {
    title: "Log a skill run",
    description:
      "Call right after a skill gives its answer. Stores the question and answer and returns a run_id. " +
      "Keep the run_id and pass it to log_rating when the user rates the answer.",
    inputSchema: z.object({
      skill_name: skillName,
      skill_version: z.string().max(50).optional(),
      user_identity: userIdentity,
      question: z.string().min(1).max(4000).describe("The user's request, in their words"),
      answer: z.string().min(1).max(20000).describe("The skill's final answer text"),
      metadata: z.record(z.string(), z.unknown()).optional()
        .describe("Optional skill-specific details, e.g. persona, jtbd, map_json"),
    }),
  }, async (a) => {
    if (await overRateLimit(a.user_identity)) return fail("Not logged: too many events, try again in a minute.");
    const run_id = crypto.randomUUID();
    const { error } = await db.from(TABLE).insert({
      event_type: "run",
      run_id,
      skill_name: a.skill_name,
      skill_version: a.skill_version ?? null,
      user_identity: a.user_identity,
      question: a.question,
      answer: a.answer,
      metadata: a.metadata ?? {},
    });
    if (error) return fail(`Not logged: ${error.message}`);
    return text(`Logged. run_id: ${run_id}`);
  });

  server.registerTool("log_rating", {
    title: "Log the user's rating",
    description: "Call when the user rates an answer previously logged with log_run. They reply 1 (up) or 0 (down).",
    inputSchema: z.object({
      run_id: z.uuid().describe("The run_id returned by log_run"),
      skill_name: skillName,
      user_identity: userIdentity,
      rating: z.enum(["up", "down", "1", "0"]).transform((r) => (r === "1" ? "up" : r === "0" ? "down" : r))
        .describe('"up" or "down". The user\'s 1 means "up" and 0 means "down".'),
      comment: z.string().max(2000).optional().describe("What the user said was missing or good"),
      followup_count: z.number().int().min(0).max(100).optional(),
    }),
  }, async (a) => {
    if (await overRateLimit(a.user_identity)) return fail("Not logged: too many events, try again in a minute.");
    const { data: run, error: lookupError } = await db.from(TABLE)
      .select("skill_name")
      .eq("run_id", a.run_id)
      .eq("event_type", "run")
      .maybeSingle();
    if (lookupError) return fail(`Not logged: ${lookupError.message}`);
    if (!run) return fail("Not logged: unknown run_id. Call log_run first.");
    if (run.skill_name !== a.skill_name) return fail("Not logged: run_id belongs to a different skill.");

    const { error } = await db.from(TABLE).insert({
      event_type: "rating",
      run_id: a.run_id,
      skill_name: a.skill_name,
      user_identity: a.user_identity,
      rating: a.rating,
      comment: a.comment ?? null,
      followup_count: a.followup_count ?? null,
    });
    if (error) return fail(`Not logged: ${error.message}`);
    return text("Rating logged. Thank you!");
  });

  server.registerTool("connect_skill", {
    title: "Connect a skill to Tuning Fork",
    description:
      "For skill authors. Returns the exact block to append to the end of the skill's SKILL.md " +
      "so the skill logs runs and ratings to Tuning Fork. Append it as-is, then show the author the change.",
    inputSchema: z.object({
      skill_name: skillName,
      skill_version: z.string().max(50).default("1.0.0"),
    }),
  }, ({ skill_name, skill_version }) => text(snippetFor(skill_name, skill_version)));

  return server;
}

export default {
  fetch: withSupabase({ auth: "none" }, (req, ctx) =>
    createMcpHandler(() => buildServer(ctx.supabaseAdmin)).fetch(req)),
};
