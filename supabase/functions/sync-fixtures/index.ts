// =====================================================================
// sync-fixtures Edge Function
// API anahtarı SADECE burada, sunucu tarafı environment variable olarak
// kullanılır. Mobil uygulama bu key'i asla görmez.
//
// Bu fonksiyon pg_cron tarafından günde birkaç kez tetiklenir ve
// aktif liglerdeki günün maçlarını + istatistiklerini API-Football'dan
// çekip Supabase'e cache'ler. API'nin 100 istek/gün limitini aşmamak
// için her çağrıda kalan kotayı kontrol eder ve aşarsa erken durur.
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const API_FOOTBALL_KEY = Deno.env.get("API_FOOTBALL_KEY")!;
const API_BASE = "https://v3.football.api-sports.io";
const DAILY_QUOTA = 100;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

async function apiFootballFetch(path: string, params: Record<string, string> = {}) {
  const url = new URL(API_BASE + path);
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v));
  const res = await fetch(url.toString(), {
    headers: { "x-apisports-key": API_FOOTBALL_KEY },
  });
  if (!res.ok) throw new Error(`API-Football hata: ${res.status}`);
  return res.json();
}

async function getRemainingQuota(): Promise<number> {
  const { data } = await supabase
    .from("app_settings")
    .select("value")
    .eq("key", "api_requests_used_today")
    .single();
  const used = Number(data?.value ?? 0);
  return DAILY_QUOTA - used;
}

async function incrementQuotaUsage(n = 1) {
  const { data } = await supabase
    .from("app_settings")
    .select("value")
    .eq("key", "api_requests_used_today")
    .single();
  const used = Number(data?.value ?? 0) + n;
  await supabase
    .from("app_settings")
    .update({ value: used })
    .eq("key", "api_requests_used_today");
}

Deno.serve(async (_req) => {
  try {
    let remaining = await getRemainingQuota();
    if (remaining <= 5) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "Günlük API kotası neredeyse doldu" }),
        { status: 200 },
      );
    }

    // 1) Aktif ligleri al
    const { data: leagues } = await supabase
      .from("leagues")
      .select("id, api_league_id, name")
      .eq("active", true);

    if (!leagues || leagues.length === 0) {
      return new Response(JSON.stringify({ skipped: true, reason: "Aktif lig yok" }), { status: 200 });
    }

    const today = new Date().toISOString().slice(0, 10);
    let syncedFixtures = 0;

    for (const league of leagues) {
      if (remaining <= 2) break; // kota tükeniyor, güvenli dur

      // Günün fikstürlerini çek (1 istek)
      const season = new Date().getFullYear();
      const fixturesRes = await apiFootballFetch("/fixtures", {
        league: String(league.api_league_id),
        season: String(season),
        date: today,
      });
      remaining--; await incrementQuotaUsage(1);

      const fixtures = fixturesRes.response ?? [];

      for (const f of fixtures) {
        // Takımları upsert et
        const homeTeam = await upsertTeam(f.teams.home, league.id);
        const awayTeam = await upsertTeam(f.teams.away, league.id);

        // Hakem (fixture içinde geliyorsa ekstra istek gerekmez)
        let refereeId: number | null = null;
        if (f.fixture.referee) {
          refereeId = await upsertReferee(f.fixture.referee);
        }

        const { data: fixtureRow } = await supabase
          .from("fixtures")
          .upsert({
            api_fixture_id: f.fixture.id,
            league_id: league.id,
            home_team_id: homeTeam,
            away_team_id: awayTeam,
            referee_id: refereeId,
            match_date: f.fixture.date,
            venue: f.fixture.venue?.name ?? null,
            status: mapStatus(f.fixture.status.short),
            home_goals: f.goals.home,
            away_goals: f.goals.away,
            updated_at: new Date().toISOString(),
          }, { onConflict: "api_fixture_id" })
          .select("id")
          .single();

        syncedFixtures++;

        // Detaylı istatistik (korner/kart) - kota izin veriyorsa ve maç
        // oynanmışsa/canlıysa çek (henüz oynanmamış maçlarda bu veri yok)
        if (remaining > 2 && fixtureRow && ["1H", "2H", "FT", "HT"].includes(f.fixture.status.short)) {
          const statsRes = await apiFootballFetch("/fixtures/statistics", {
            fixture: String(f.fixture.id),
          });
          remaining--; await incrementQuotaUsage(1);
          await saveFixtureStats(fixtureRow.id, statsRes.response ?? []);
        }
      }
    }

    await supabase.from("app_settings").update({ value: new Date().toISOString() }).eq("key", "last_sync_at");

    return new Response(
      JSON.stringify({ ok: true, syncedFixtures, remainingQuota: remaining }),
      { status: 200 },
    );
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), { status: 500 });
  }
});

async function upsertTeam(team: any, leagueId: number): Promise<number> {
  const { data } = await supabase
    .from("teams")
    .upsert({
      api_team_id: team.id,
      name: team.name,
      logo_url: team.logo,
      league_id: leagueId,
    }, { onConflict: "api_team_id" })
    .select("id")
    .single();
  return data!.id;
}

async function upsertReferee(name: string): Promise<number> {
  const { data } = await supabase
    .from("referees")
    .upsert({ name }, { onConflict: "name" })
    .select("id")
    .single();
  return data!.id;
}

function mapStatus(short: string): string {
  if (["1H", "2H", "HT", "LIVE"].includes(short)) return "live";
  if (short === "FT" || short === "AET" || short === "PEN") return "finished";
  if (short === "PST" || short === "CANC") return "postponed";
  return "scheduled";
}

async function saveFixtureStats(fixtureId: number, statsResponse: any[]) {
  if (!statsResponse || statsResponse.length < 2) return; // veri yoksa hiç yazma - UYDURMA
  const find = (teamStats: any, type: string) =>
    teamStats.statistics.find((s: any) => s.type === type)?.value ?? null;

  const home = statsResponse[0];
  const away = statsResponse[1];

  const corners_home = find(home, "Corner Kicks");
  const corners_away = find(away, "Corner Kicks");
  const yellow_home = find(home, "Yellow Cards");
  const yellow_away = find(away, "Yellow Cards");
  const red_home = find(home, "Red Cards");
  const red_away = find(away, "Red Cards");
  const fouls_home = find(home, "Fouls");
  const fouls_away = find(away, "Fouls");

  const fields = [corners_home, corners_away, yellow_home, yellow_away, red_home, red_away, fouls_home, fouls_away];
  const completeness = fields.filter((f) => f !== null && f !== undefined).length / fields.length;

  await supabase.from("fixture_stats").upsert({
    fixture_id: fixtureId,
    corners_home, corners_away,
    yellow_home, yellow_away,
    red_home, red_away,
    fouls_home, fouls_away,
    data_completeness: completeness,
    updated_at: new Date().toISOString(),
  }, { onConflict: "fixture_id" });
}
