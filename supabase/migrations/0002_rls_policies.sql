-- =====================================================================
-- 0002_rls_policies.sql
-- KRİTİK: Admin yetkisi ve günlük limit SADECE burada, backend'de korunur.
-- Kullanıcı kendi is_admin / daily_limit / can_view_coupons alanını
-- ASLA client'tan değiştiremez.
-- =====================================================================

alter table public.profiles enable row level security;
alter table public.leagues enable row level security;
alter table public.teams enable row level security;
alter table public.referees enable row level security;
alter table public.fixtures enable row level security;
alter table public.fixture_stats enable row level security;
alter table public.team_form_summary enable row level security;
alter table public.predictions enable row level security;
alter table public.coupons enable row level security;
alter table public.coupon_items enable row level security;
alter table public.usage_log enable row level security;
alter table public.app_settings enable row level security;

-- Yardımcı fonksiyon: çağıran kullanıcı admin mi?
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (select is_admin from public.profiles where id = auth.uid()), false
  );
$$;

-- ---------- PROFILES ----------
-- Kullanıcı sadece kendi satırını okuyabilir; admin herkesi okuyabilir.
create policy profiles_select on public.profiles
  for select using (auth.uid() = id or public.is_admin());

-- Kullanıcı kendi satırını GÜNCELLEYEBİLİR ama sadece belirli sütunları
-- (is_admin, daily_limit, can_view_coupons, used_today burada YOK -
--  bu alanlar sadece admin RPC'leri veya trigger'lar tarafından değiştirilir)
create policy profiles_update_self on public.profiles
  for update using (auth.uid() = id)
  with check (
    auth.uid() = id
    -- kritik alanlar aşağıdaki trigger ile korunuyor (bkz 0003)
  );

create policy profiles_admin_all on public.profiles
  for all using (public.is_admin());

-- ---------- LEAGUES / TEAMS / REFEREES / FIXTURES / STATS (herkes okuyabilir) ----------
create policy leagues_read on public.leagues for select using (true);
create policy leagues_admin_write on public.leagues for insert with check (public.is_admin());
create policy leagues_admin_update on public.leagues for update using (public.is_admin());

create policy teams_read on public.teams for select using (true);
create policy referees_read on public.referees for select using (true);
create policy fixtures_read on public.fixtures for select using (true);
create policy fixture_stats_read on public.fixture_stats for select using (true);
create policy team_form_read on public.team_form_summary for select using (true);

-- ---------- PREDICTIONS ----------
-- Herkes tahminleri görebilir; GÖRÜNTÜLEME hakkı (günlük 5) uygulama
-- katmanında use_prediction() RPC'si ile ayrıca kontrol edilir (bkz 0003).
create policy predictions_read on public.predictions for select using (true);
create policy predictions_admin_write on public.predictions for all using (public.is_admin());

-- ---------- COUPONS ----------
-- Sadece can_view_coupons=true olan kullanıcılar YAYINLANMIŞ kuponları görebilir.
create policy coupons_read on public.coupons
  for select using (
    published = true and (
      public.is_admin() or
      coalesce((select can_view_coupons from public.profiles where id = auth.uid()), false)
    )
  );
create policy coupons_admin_write on public.coupons for all using (public.is_admin());
create policy coupon_items_read on public.coupon_items
  for select using (
    exists (
      select 1 from public.coupons c
      where c.id = coupon_id and c.published = true and (
        public.is_admin() or
        coalesce((select can_view_coupons from public.profiles where id = auth.uid()), false)
      )
    )
  );
create policy coupon_items_admin_write on public.coupon_items for all using (public.is_admin());

-- ---------- USAGE LOG ----------
-- Kullanıcı sadece kendi kayıtlarını okuyabilir. YAZMA client'tan YASAK -
-- yazma yalnızca use_prediction() SECURITY DEFINER fonksiyonu üzerinden olur.
create policy usage_log_read on public.usage_log
  for select using (auth.uid() = user_id or public.is_admin());

-- ---------- APP SETTINGS ----------
create policy app_settings_admin on public.app_settings for all using (public.is_admin());
create policy app_settings_read on public.app_settings for select using (true);
