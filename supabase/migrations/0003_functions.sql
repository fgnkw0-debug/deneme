-- =====================================================================
-- 0003_functions.sql
-- Günlük 5 tahmin hakkının ve admin yetkilerinin backend'de zorunlu
-- kılınması. Bütün mantık cihaz saatinden bağımsız, Postgres now()
-- (server saati, UTC) kullanır.
-- =====================================================================

-- 1) Yeni kullanıcı kayıt olduğunda profiles satırı otomatik oluşturulsun
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2) Kullanıcı kendi profilini güncellerken kritik alanları
--    değiştiremesin (is_admin, daily_limit, can_view_coupons, used_today).
--    Sadece admin veya bu dosyadaki RPC'ler bu alanları değiştirebilir.
create or replace function public.protect_critical_profile_fields()
returns trigger
language plpgsql
security definer
as $$
begin
  if not public.is_admin() then
    new.is_admin := old.is_admin;
    new.daily_limit := old.daily_limit;
    new.can_view_coupons := old.can_view_coupons;
    new.used_today := old.used_today;
    new.last_reset_date := old.last_reset_date;
    new.is_active := old.is_active;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_profile on public.profiles;
create trigger trg_protect_profile
  before update on public.profiles
  for each row execute function public.protect_critical_profile_fields();

-- 3) GÜNÜN GÜNLÜK HAKKI - server tarihine göre otomatik reset
--    Bu fonksiyon her istekte çağrılır; last_reset_date bugünden
--    eskiyse used_today sıfırlanır.
create or replace function public.ensure_daily_reset(p_user uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_today date := (now() at time zone 'utc')::date;
begin
  update public.profiles
  set used_today = 0, last_reset_date = v_today
  where id = p_user and last_reset_date < v_today;
end;
$$;

-- 4) use_prediction: kullanıcı bir maçın tahminini "açtığında" çağrılır.
--    - Admin ise limit kontrolü yapılmaz.
--    - Normal kullanıcı günlük daily_limit'i aşamaz.
--    - Aynı maç aynı gün tekrar açılırsa hak TEKRAR harcanmaz (unique index).
--    Bu fonksiyon SECURITY DEFINER olduğu için client bunu bypass edemez;
--    tüm kontrol ve yazma sunucu tarafında, tek bir atomik işlemde olur.
create or replace function public.use_prediction(p_fixture_id bigint)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_profile record;
  v_already_used boolean;
begin
  if v_uid is null then
    raise exception 'Yetkisiz istek';
  end if;

  perform public.ensure_daily_reset(v_uid);

  select * into v_profile from public.profiles where id = v_uid for update;

  if not v_profile.is_active then
    raise exception 'Hesap pasif durumda';
  end if;

  select exists(
    select 1 from public.usage_log
    where user_id = v_uid and fixture_id = p_fixture_id
      and used_on = (now() at time zone 'utc')::date
  ) into v_already_used;

  if v_already_used then
    return jsonb_build_object('allowed', true, 'already_counted', true,
      'remaining', greatest(v_profile.daily_limit - v_profile.used_today, 0));
  end if;

  if not v_profile.is_admin and v_profile.used_today >= v_profile.daily_limit then
    return jsonb_build_object('allowed', false, 'remaining', 0,
      'message', 'Bugünkü ücretsiz tahmin hakkınız doldu.');
  end if;

  insert into public.usage_log(user_id, fixture_id) values (v_uid, p_fixture_id);

  if not v_profile.is_admin then
    update public.profiles set used_today = used_today + 1 where id = v_uid;
  end if;

  return jsonb_build_object(
    'allowed', true, 'already_counted', false,
    'remaining', case when v_profile.is_admin then null
                 else greatest(v_profile.daily_limit - v_profile.used_today - 1, 0) end
  );
end;
$$;

-- 5) Admin RPC: bir kullanıcının günlük limitini / yetkilerini değiştir
create or replace function public.admin_update_user(
  p_user_id uuid,
  p_daily_limit integer default null,
  p_is_admin boolean default null,
  p_can_view_coupons boolean default null,
  p_is_active boolean default null
) returns void
language plpgsql
security definer
as $$
begin
  if not public.is_admin() then
    raise exception 'Yalnızca admin bu işlemi yapabilir';
  end if;
  update public.profiles set
    daily_limit = coalesce(p_daily_limit, daily_limit),
    is_admin = coalesce(p_is_admin, is_admin),
    can_view_coupons = coalesce(p_can_view_coupons, can_view_coupons),
    is_active = coalesce(p_is_active, is_active)
  where id = p_user_id;
end;
$$;

-- 6) Admin dashboard için tek sorguluk özet
create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Yalnızca admin bu işlemi yapabilir';
  end if;
  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    'active_users', (select count(*) from public.profiles where is_active),
    'today_active_users', (select count(distinct user_id) from public.usage_log
                            where used_on = (now() at time zone 'utc')::date),
    'today_predictions_used', (select count(*) from public.usage_log
                                where used_on = (now() at time zone 'utc')::date),
    'today_fixtures', (select count(*) from public.fixtures
                        where match_date::date = (now() at time zone 'utc')::date),
    'published_coupons', (select count(*) from public.coupons where published = true),
    'api_requests_used_today', (select value from public.app_settings where key = 'api_requests_used_today')
  ) into v_result;
  return v_result;
end;
$$;
