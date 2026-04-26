-- ============================================================
-- Tracking Velocidade — Schema Supabase
-- Extensões: TimescaleDB (séries temporais) + PostGIS (geo)
--
-- Como aplicar:
--   1. Painel Supabase → SQL Editor → cole este arquivo → Run
--   2. Ou: psql -h db.<ref>.supabase.co -U postgres -d postgres -f schema.sql
-- ============================================================

-- ── Extensões ────────────────────────────────────────────────────────────────
-- TimescaleDB é pré-instalado no Supabase; basta habilitar.
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

-- ── Tabela: users ─────────────────────────────────────────────────────────────
-- Liga o Firebase UID ao status de assinatura armazenado aqui.
CREATE TABLE IF NOT EXISTS users (
  firebase_uid           TEXT        PRIMARY KEY,
  email                  TEXT,
  subscription_status    TEXT        NOT NULL DEFAULT 'trial'
                                     CHECK (subscription_status IN
                                       ('trial','active','past_due','canceled','expired')),
  preapproval_id         TEXT,                          -- ID da preapproval no MP
  subscription_renews_at TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Tabela: trips ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trips (
  id            TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id       TEXT        NOT NULL REFERENCES users(firebase_uid) ON DELETE CASCADE,
  started_at    TIMESTAMPTZ NOT NULL,
  ended_at      TIMESTAMPTZ,
  avg_speed_kmh REAL,
  max_speed_kmh REAL,
  distance_km   REAL,
  start_address TEXT,
  end_address   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trips_user_started ON trips (user_id, started_at DESC);

-- ── Tabela: speed_records (hypertable TimescaleDB) ───────────────────────────
-- Cada linha = leitura do GPS a cada ~3 s enquanto em movimento.
-- TimescaleDB particiona automaticamente por recorded_at (chunks mensais).
CREATE TABLE IF NOT EXISTS speed_records (
  id            BIGSERIAL,
  trip_id       TEXT        NOT NULL,   -- FK lógica (sem REFERENCES para performance)
  user_id       TEXT        NOT NULL,
  recorded_at   TIMESTAMPTZ NOT NULL,
  speed_kmh     REAL        NOT NULL,
  max_speed_kmh REAL        NOT NULL,
  -- PostGIS: armazena lat/lon como ponto geográfico (SRID 4326 = WGS84)
  location      GEOGRAPHY(Point, 4326),
  accuracy_m    REAL,
  PRIMARY KEY (id, recorded_at)         -- compound PK exigido pelo TimescaleDB
);

-- Converte em hypertable particionada por tempo
SELECT create_hypertable(
  'speed_records', 'recorded_at',
  if_not_exists => TRUE,
  chunk_time_interval => INTERVAL '1 month'
);

-- Índices para queries comuns
CREATE INDEX IF NOT EXISTS idx_sr_user_time  ON speed_records (user_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_sr_trip       ON speed_records (trip_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_sr_location   ON speed_records USING GIST (location);

-- Compressão automática após 30 dias (economiza ~90% de espaço)
ALTER TABLE speed_records SET (
  timescaledb.compress,
  timescaledb.compress_orderby    = 'recorded_at DESC',
  timescaledb.compress_segmentby  = 'user_id'
);

SELECT add_compression_policy(
  'speed_records',
  INTERVAL '30 days',
  if_not_exists => TRUE
);

-- ── Row Level Security ────────────────────────────────────────────────────────
-- O backend usa a service_role key (ignora RLS).
-- Essas policies protegem caso o Flutter use a anon key diretamente no futuro.
ALTER TABLE users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips         ENABLE ROW LEVEL SECURITY;
ALTER TABLE speed_records ENABLE ROW LEVEL SECURITY;

-- Usuário só lê/escreve os próprios dados.
-- (auth.uid() é o UUID do Supabase Auth — se migrar para Supabase Auth no futuro)
CREATE POLICY "own_users" ON users
  USING (firebase_uid = current_setting('app.current_user_id', TRUE));

CREATE POLICY "own_trips" ON trips
  USING (user_id = current_setting('app.current_user_id', TRUE));

CREATE POLICY "own_records" ON speed_records
  USING (user_id = current_setting('app.current_user_id', TRUE));

-- ── Trigger: updated_at automático ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── View: resumo diário (útil para dashboard) ─────────────────────────────────
CREATE OR REPLACE VIEW daily_summary AS
SELECT
  user_id,
  time_bucket('1 day', recorded_at)  AS day,
  AVG(speed_kmh)                      AS avg_speed_kmh,
  MAX(speed_kmh)                      AS max_speed_kmh,
  COUNT(*)                            AS total_readings
FROM speed_records
GROUP BY user_id, day;
