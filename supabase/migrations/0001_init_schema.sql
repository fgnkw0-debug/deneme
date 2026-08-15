-- =====================================================================
-- 0001_init_schema.sql
-- Online Maç İstatistik & Tahmin Uygulaması - Ana Şema
-- =====================================================================

-- Kullanıcıların uygulamaya özel bilgileri (auth.users tablosunun uzantısı)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  membership_type text not null default 'free', -- free | premium | admin
  daily_limit integer not null default 5,
  used_today integer not null default 0,
  last_reset_date date not null default (now() at time zone 'utc')::date,
  is_admin boolean not null default false,
  is_active boolean not null default true,
  can_view_coupons boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.leagues (
  id bigserial primary key,
  api_league_id integer unique not null,
  name text not null,
  country text,
  logo_url text,
  active boolean not null default true
);

create table if not exists public.teams (
  id bigserial primary key,
  api_team_id integer unique not null,
  name text not null,
  logo_url text,
  league_id bigint references public.leagues(id)
);

create table if not exists public.referees (
  id bigserial primary key,
  name text not null unique,
  matches_officiated integer default 0,
  avg_yellow_cards numeric,
  avg_red_cards numeric,
  avg_fouls numeric,
  avg_penalties numeric,
  home_win_rate numeric,
  draw_rate numeric,
  away_win_rate numeric,
  last5_card_trend numeric,
  last10_card_trend numeric,
  updated_at timestamptz default now()
);

create table if not exists public.fixtures (
  id bigserial primary key,
  api_fixture_id integer unique not null,
  league_id bigint references public.leagues(id),
  home_team_id bigint references public.teams(id),
  away_team_id bigint references public.teams(id),
  referee_id bigint references public.referees(id),
  match_date timestamptz not null,
  venue text,
  status text not null default 'scheduled', -- scheduled | live | finished | postponed
  home_goals integer,
  away_goals integer,
  updated_at timestamptz default now()
);
create index if not exists idx_fixtures_date on public.fixtures(match_date);
create index if not exists idx_fixtures_league on public.fixtures(league_id);

-- Bir maça ait ham istatistik verisi (gol, korner, kart) - null = veri yok
create table if not exists public.fixture_stats (
  fixture_id bigint primary key references public.fixtures(id) on delete cascade,
  corners_home integer,
  corners_away integer,
  corners_home_1h integer,
  corners_away_1h integer,
  yellow_home integer,
  yellow_away integer,
  red_home integer,
  red_away integer,
  fouls_home integer,
  fouls_away integer,
  data_completeness numeric default 0, -- 0-1 arası, kaç alanın dolu olduğu
  updated_at timestamptz default now()
);

-- Takımların hesaplanmış form/performans özetleri (cache - her sync'te güncellenir)
create table if not exists public.team_form_summary (
  team_id bigint primary key references public.teams(id) on delete cascade,
  last5_wins integer, last5_draws integer, last5_losses integer,
  last10_wins integer, last10_draws integer, last10_losses integer,
  goals_scored_avg numeric, goals_conceded_avg numeric,
  home_goals_scored_avg numeric, home_goals_conceded_avg numeric,
  away_goals_scored_avg numeric, away_goals_conceded_avg numeric,
  corners_avg numeric, corners_conceded_avg numeric,
  cards_avg numeric,
  sample_size integer default 0, -- kaç maçtan hesaplandığı (güven için kritik)
  updated_at timestamptz default now()
);

-- Motorun ürettiği tahminler (market bazında ayrı satır)
create table if not exists public.predictions (
  id bigserial primary key,
  fixture_id bigint references public.fixtures(id) on delete cascade,
  market text not null,          -- ör: '2.5_UST', 'MS1', '9.5_KORNER_UST', 'KG_VAR'
  category text not null,        -- 'MAC_SONUCU' | 'GOL' | 'KORNER' | 'KART' | 'HAKEM'
  prediction_value text not null,-- gösterilecek etiket, ör: '2.5 ÜST'
  confidence numeric not null,   -- 0-100
  form_score numeric,
  goal_score numeric,
  home_away_score numeric,
  corner_score numeric,
  card_score numeric,
  referee_score numeric,
  h2h_score numeric,
  data_sufficient boolean not null default true,
  computed_at timestamptz default now(),
  unique(fixture_id, market)
);

create table if not exists public.coupons (
  id bigserial primary key,
  title text not null,
  coupon_type text not null, -- 'single' | 'triple' | 'quintuple'
  description text,
  published boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

create table if not exists public.coupon_items (
  id bigserial primary key,
  coupon_id bigint references public.coupons(id) on delete cascade,
  fixture_id bigint references public.fixtures(id),
  prediction_id bigint references public.predictions(id),
  sort_order integer default 0
);

-- Günlük hakkın SERVER tarihine göre güvenli takibi (cihaz saati manipülasyonuna kapalı)
create table if not exists public.usage_log (
  id bigserial primary key,
  user_id uuid references public.profiles(id) on delete cascade,
  fixture_id bigint references public.fixtures(id),
  used_on date not null default (now() at time zone 'utc')::date,
  created_at timestamptz default now()
);
create unique index if not exists idx_usage_unique on public.usage_log(user_id, fixture_id, used_on);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null
);

insert into public.app_settings(key, value) values
  ('api_daily_quota', '100'),
  ('api_requests_used_today', '0'),
  ('last_sync_at', 'null')
on conflict (key) do nothing;
