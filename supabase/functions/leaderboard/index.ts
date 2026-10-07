import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "content-type",
};

const jsonHeaders = {
  ...corsHeaders,
  "content-type": "application/json; charset=utf-8",
  "cache-control": "public, max-age=60, s-maxage=300",
  "x-content-type-options": "nosniff",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY are required.");
}

const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { persistSession: false },
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed." }), {
      status: 405,
      headers: { ...jsonHeaders, allow: "GET, OPTIONS" },
    });
  }

  const { data, error } = await supabase
    .from("tuningfork_skill_leaderboard")
    .select(
      "rank,skill_name,bayesian_score,approval_rate,rating_rate,total_runs,rated_runs,upvotes,downvotes,last_run_at",
    )
    .order("rank");

  if (error) {
    console.error("Unable to load leaderboard:", error);
    return new Response(
      JSON.stringify({ error: "Unable to load the leaderboard." }),
      { status: 500, headers: jsonHeaders },
    );
  }

  return new Response(JSON.stringify(data ?? []), { headers: jsonHeaders });
});
