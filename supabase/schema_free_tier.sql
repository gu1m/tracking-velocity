-- ============================================================
-- Tracking Velocidade — Schema Supabase (Free Tier)
-- SEM TimescaleDB (adicione depois em planos pagos)
-- COM PostGIS e RLS habilitados
-- ============================================================

-- ── Extensões ────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Tabela: users ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  firebase_uid           TEXT        PRIMARY KEY,
  email                  TEXT,
  subscription_status    TEXT        NOT NULL DEFAULT 'trial'
                                     CHECK (subscription_status IN
                                       ('trial','active','past_due','canceled','expired')),
  preapproval_id         TEXT,
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

-- ── Tabela: speed_records ────────────────────────────────────────────────────
-- Versão simples (sem hypertable) — suficiente para MVP
CREATE TABLE IF NOT EXISTS speed_records (
  id            BIGSERIAL   PRIMARY KEY,
  trip_id       TEXT        NOT NULL,
  user_id       TEXT        NOT NULL,
  recorded_at   TIMESTAMPTZ NOT NULL,
  speed_kmh     REAL        NOT NULL,
  max_speed_kmh REAL        NOT NULL,
  location      GEOGRAPHY(Point, 4326),
  accuracy_m    REAL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sr_user_time  ON speed_records (user_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_sr_trip       ON speed_records (trip_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_sr_location   ON speed_records USING GIST (location);

-- ── Row Level Security ────────────────────────────────────────────────────────
ALTER TABLE users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips         ENABLE ROW LEVEL SECURITY;
ALTER TABLE speed_records ENABLE ROW LEVEL SECURITY;

-- Políticas simples (o backend usa service_role, então estas são só para o futuro)
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

-- ── View: resumo simples ─────────────────────────────────────────────────────
CREATE OR REPLACE VIEW trip_summary AS
SELECT
  trips.id,
  trips.user_id,
  trips.started_at,
  trips.ended_at,
  trips.avg_speed_kmh,
  trips.max_speed_kmh,
  trips.distance_km,
  COUNT(sr.id) AS record_count
FROM trips
LEFT JOIN speed_records sr ON sr.trip_id = trips.id
GROUP BY trips.id, trips.user_id, trips.started_at, trips.ended_at,
         trips.avg_speed_kmh, trips.max_speed_kmh, trips.distance_km;
