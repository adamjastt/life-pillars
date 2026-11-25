// Life Pillars: sends lock-screen alerts to everyone in a fishing session.
// Secrets needed (Edge Functions > Secrets): VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

const URL_ = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
webpush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT") ?? "mailto:lifepillars@example.com",
  Deno.env.get("VAPID_PUBLIC_KEY")!,
  Deno.env.get("VAPID_PRIVATE_KEY")!,
);

const weight = (g?: number | null) => {
  if (!g) return "";
  let oz = Math.round(g / 28.349523), lb = Math.floor(oz / 16);
  oz -= lb * 16;
  return lb ? `${lb} lb ${oz} oz` : `${oz} oz`;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const me = createClient(URL_, ANON, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const { data: { user } } = await me.auth.getUser();
    if (!user) return json({ error: "not signed in" }, 401);
    const body = await req.json().catch(() => ({}));
    const db = createClient(URL_, SERVICE);
    const { data: who } = await db.from("profiles").select("name").eq("user_id", user.id).maybeSingle();
    const name = who?.name || "A mate";

    let sid = "", title = "", text = "", tag = "";
    let only: string[] | null = null;
    if (body.event_id) {
      const { data: ev } = await db.from("session_events").select("*").eq("id", body.event_id).maybeSingle();
      if (!ev || ev.user_id !== user.id) return json({ error: "not yours" }, 403);
      if (ev.pushed_at) return json({ ok: true, sent: 0, repeat: true });
      await db.from("session_events").update({ pushed_at: new Date().toISOString() }).eq("id", ev.id);
      const { data: s } = await db.from("sessions").select("name").eq("id", ev.session_id).maybeSingle();
      const i = ev.info || {}, sp = i.sp || "fish";
      sid = ev.session_id;
      title = `${name} caught ${/^[aeiou]/i.test(sp) ? "an" : "a"} ${sp}`;
      text = [weight(i.g), i.cm ? `${i.cm} cm` : "", s?.name].filter(Boolean).join(" · ");
      tag = "ev-" + ev.id;
    } else if (body.session_id && body.invite) {
      const { data: s } = await db.from("sessions").select("*").eq("id", body.session_id).maybeSingle();
      if (!s || s.owner !== user.id) return json({ error: "not the host" }, 403);
      sid = s.id;
      title = `${name} started a session`;
      text = `${s.name}. You're in, tap to follow along.`;
      tag = "ses-" + s.id;
      if (Array.isArray(body.users)) only = body.users;
    } else return json({ error: "nothing to send" }, 400);

    const { data: mem } = await db.from("session_members").select("user_id").eq("session_id", sid);
    let to = (mem || []).map((m) => m.user_id).filter((u) => u !== user.id);
    if (only) to = to.filter((u) => only!.includes(u));
    if (!to.length) return json({ ok: true, sent: 0 });
    const { data: subs } = await db.from("push_subs").select("*").in("user_id", to);
    const payload = JSON.stringify({ title, body: text, tag, url: `./?s=${sid}#session` });
    let sent = 0;
    await Promise.all((subs || []).map(async (s) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 3600, urgency: "high" });
        sent++;
      } catch (e) {
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) await db.from("push_subs").delete().eq("endpoint", s.endpoint);
      }
    }));
    return json({ ok: true, sent });
  } catch (e) {
    return json({ error: String((e as Error)?.message || e) }, 500);
  }
});
