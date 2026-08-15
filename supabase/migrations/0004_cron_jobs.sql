-- =====================================================================
-- 0004_cron_jobs.sql
-- Supabase Dashboard > Database > Extensions kısmından pg_cron ve
-- pg_net eklentilerini aktif ettikten SONRA bu dosyayı çalıştırın.
-- <PROJECT_REF> ve <SERVICE_ROLE_KEY> değerlerini kendi projenizle
-- değiştirin (README'de nasıl bulunacağı anlatılıyor).
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Günde 4 kez (00:00, 06:00, 12:00, 18:00 UTC) fikstür/istatistik senkronu
select cron.schedule(
  'sync-fixtures-job',
  '0 0,6,12,18 * * *',
  $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/sync-fixtures',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <SERVICE_ROLE_KEY>',
      'Content-Type', 'application/json'
    )
  );
  $$
);

-- Senkrondan 10 dakika sonra tahminleri yeniden hesapla
select cron.schedule(
  'compute-predictions-job',
  '10 0,6,12,18 * * *',
  $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/compute-predictions',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <SERVICE_ROLE_KEY>',
      'Content-Type', 'application/json'
    )
  );
  $$
);

-- Her gün 00:05 UTC'de API kota sayacını sıfırla (API-Football kotası
-- 00:00 UTC'de resetlenir)
select cron.schedule(
  'reset-api-quota-job',
  '5 0 * * *',
  $$
  update public.app_settings set value = '0' where key = 'api_requests_used_today';
  $$
);
