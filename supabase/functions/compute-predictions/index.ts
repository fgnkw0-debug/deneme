// =====================================================================
// compute-predictions Edge Function
// sync-fixtures'tan sonra çalışır. team_form_summary ve fixture_stats
// tablolarındaki GERÇEK verilerden ağırlıklı tahmin skorları üretir.
//
// TEMEL KURAL: Bir bileşen için veri yoksa (null / sample_size düşük)
// o bileşen skora dahil edilmez ve toplam "confidence" otomatik düşer.
// Hiçbir zaman rastgele/uydurma değer üretilmez.
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// Ağırlıklar - V1'de sabit başlangıç değerleri, V2'de backtest ile kalibre edilecek
const WEIGHTS = {
  form: 0.22,
  goal: 0.22,
  homeAway: 0.14,
  corner: 0.14,
  card: 0.12,
  referee: 0.08,
  h2h: 0.08,
};
const MIN_SAMPLE_SIZE = 5; // bundan az maç verisi varsa o bileşen "yetersiz" sayılır

Deno.serve(async (_req) => {
  try {
    const { data: fixtures } = await supabase
      .from("fixtures")
      .select("id, home_team_id, away_team_id, referee_id, status")
      .eq("status", "scheduled")
      .gte("match_date", new Date().toISOString())
      .lte("match_date", new Date(Date.now() + 3 * 86400000).toISOString());

    if (!fixtures) return new Response(JSON.stringify({ ok: true, processed: 0 }));

    let processed = 0;
    for (const fx of fixtures) {
      await computeForFixture(fx);
      processed++;
    }

    return new Response(JSON.stringify({ ok: true, processed }), { status: 200 });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), { status: 500 });
  }
});

async function computeForFixture(fx: any) {
  const [{ data: homeForm }, { data: awayForm }, { data: referee }] = await Promise.all([
    supabase.from("team_form_summary").select("*").eq("team_id", fx.home_team_id).maybeSingle(),
    supabase.from("team_form_summary").select("*").eq("team_id", fx.away_team_id).maybeSingle(),
    fx.referee_id
      ? supabase.from("referees").select("*").eq("id", fx.referee_id).maybeSingle()
      : Promise.resolve({ data: null }),
  ]);

  const components = buildComponents(homeForm, awayForm, referee);
  const predictions = buildPredictions(components);

  for (const p of predictions) {
    await supabase.from("predictions").upsert({
      fixture_id: fx.id,
      market: p.market,
      category: p.category,
      prediction_value: p.label,
      confidence: p.confidence,
      form_score: components.form.value,
      goal_score: components.goal.value,
      home_away_score: components.homeAway.value,
      corner_score: components.corner.value,
      card_score: components.card.value,
      referee_score: components.referee.value,
      h2h_score: components.h2h.value,
      data_sufficient: p.dataSufficient,
      computed_at: new Date().toISOString(),
    }, { onConflict: "fixture_id,market" });
  }
}

function sufficient(sampleSize: number | null | undefined) {
  return (sampleSize ?? 0) >= MIN_SAMPLE_SIZE;
}

// Her bileşen için { value: 0-1 arası skor | null, available: boolean }
function buildComponents(homeForm: any, awayForm: any, referee: any) {
  const bothHaveSample = sufficient(homeForm?.sample_size) && sufficient(awayForm?.sample_size);

  const form = bothHaveSample
    ? { value: normalizeFormDiff(homeForm, awayForm), available: true }
    : { value: null, available: false };

  const goal = (homeForm?.goals_scored_avg != null && awayForm?.goals_scored_avg != null)
    ? { value: normalizeGoalDiff(homeForm, awayForm), available: true }
    : { value: null, available: false };

  const homeAway = (homeForm?.home_goals_scored_avg != null && awayForm?.away_goals_scored_avg != null)
    ? { value: normalizeHomeAway(homeForm, awayForm), available: true }
    : { value: null, available: false };

  const corner = (homeForm?.corners_avg != null && awayForm?.corners_avg != null)
    ? { value: (homeForm.corners_avg + awayForm.corners_avg) / 20, available: true } // ~0-1 arası kaba normalize
    : { value: null, available: false };

  const card = (homeForm?.cards_avg != null && awayForm?.cards_avg != null)
    ? { value: (homeForm.cards_avg + awayForm.cards_avg) / 8, available: true }
    : { value: null, available: false };

  const refereeComp = (referee?.avg_yellow_cards != null && referee?.matches_officiated >= MIN_SAMPLE_SIZE)
    ? { value: Math.min(referee.avg_yellow_cards / 6, 1), available: true }
    : { value: null, available: false };

  // H2H bu V1'de team_form_summary'ye dahil değil - veri altyapısı genişleyince eklenecek
  const h2h = { value: null, available: false };

  return { form, goal, homeAway, corner, card, referee: refereeComp, h2h };
}

function normalizeFormDiff(h: any, a: any) {
  const hPts = h.last5_wins * 3 + h.last5_draws;
  const aPts = a.last5_wins * 3 + a.last5_draws;
  return clamp01(0.5 + (hPts - aPts) / 30);
}
function normalizeGoalDiff(h: any, a: any) {
  const diff = (h.goals_scored_avg - h.goals_conceded_avg) - (a.goals_scored_avg - a.goals_conceded_avg);
  return clamp01(0.5 + diff / 6);
}
function normalizeHomeAway(h: any, a: any) {
  const diff = h.home_goals_scored_avg - a.away_goals_scored_avg;
  return clamp01(0.5 + diff / 4);
}
function clamp01(v: number) { return Math.max(0, Math.min(1, v)); }

// Mevcut bileşenlerden confidence ve yön hesapla, eksik bileşenleri atla
function buildPredictions(components: Record<string, { value: number | null; available: boolean }>) {
  const results: any[] = [];
  const availableWeightSum = Object.entries(WEIGHTS)
    .filter(([k]) => components[k].available)
    .reduce((s, [, w]) => s + w, 0);

  if (availableWeightSum === 0) {
    return []; // hiç veri yok -> hiç tahmin üretme
  }

  // Örnek: 2.5 Üst/Alt tahmini (gol + form + ev/deplasman ağırlıklı)
  const goalRelevant = ["form", "goal", "homeAway"].filter((k) => components[k].available);
  if (goalRelevant.length > 0) {
    const w = goalRelevant.reduce((s, k) => s + (WEIGHTS as any)[k], 0);
    const score = goalRelevant.reduce((s, k) => s + components[k].value! * (WEIGHTS as any)[k], 0) / w;
    const confidence = Math.round(50 + (score - 0.5) * 100 * (w / (WEIGHTS.form + WEIGHTS.goal + WEIGHTS.homeAway)));
    results.push({
      market: "2.5_UST_ALT", category: "GOL",
      label: score >= 0.5 ? "2.5 ÜST" : "2.5 ALT",
      confidence: clampConfidence(confidence, goalRelevant.length, 3),
      dataSufficient: goalRelevant.length >= 2,
    });
  }

  // Korner tahmini
  if (components.corner.available) {
    const score = components.corner.value!;
    results.push({
      market: "9.5_KORNER_UST_ALT", category: "KORNER",
      label: score >= 0.5 ? "9.5 KORNER ÜST" : "9.5 KORNER ALT",
      confidence: clampConfidence(Math.round(50 + (score - 0.5) * 80), 1, 1),
      dataSufficient: true,
    });
  }

  // Kart tahmini (hakem verisiyle güçlendirilir)
  if (components.card.available) {
    const cardKeys = ["card", "referee"].filter((k) => components[k].available);
    const w = cardKeys.reduce((s, k) => s + (WEIGHTS as any)[k], 0);
    const score = cardKeys.reduce((s, k) => s + components[k].value! * (WEIGHTS as any)[k], 0) / w;
    results.push({
      market: "4.5_SARI_KART_UST_ALT", category: "KART",
      label: score >= 0.5 ? "4.5 SARI KART ÜST" : "4.5 SARI KART ALT",
      confidence: clampConfidence(Math.round(50 + (score - 0.5) * 80), cardKeys.length, 2),
      dataSufficient: cardKeys.length >= 1,
    });
  }

  return results;
}

// Kaç bileşenden hesaplandığına göre confidence'ı gerçekçi aralığa çek;
// eksik veri -> düşük güven (asla yüksek yüzde uydurma)
function clampConfidence(raw: number, availableCount: number, maxCount: number) {
  const completenessFactor = availableCount / maxCount; // 0-1
  const capped = Math.max(35, Math.min(90, raw));
  return Math.round(capped * (0.5 + 0.5 * completenessFactor));
}
