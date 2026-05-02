-- Fase 1: Tabela de assinaturas digitais de relatórios
-- Execute no Supabase: Dashboard → SQL Editor → New query

CREATE TABLE IF NOT EXISTS report_signatures (
  id            TEXT      PRIMARY KEY,          -- UUID gerado pelo backend
  user_id       TEXT      NOT NULL,             -- firebase_uid do exportador
  trip_ids      TEXT[]    NOT NULL DEFAULT '{}',-- IDs das viagens incluídas
  record_count  INTEGER   NOT NULL,             -- total de registros GPS
  record_hashes TEXT[]    NOT NULL DEFAULT '{}',-- SHA-256 de cada SpeedRecord
  canonical     TEXT      NOT NULL,             -- string canônica assinada
  signature     TEXT      NOT NULL,             -- assinatura RSA-SHA256 base64
  generated_at  TIMESTAMPTZ NOT NULL,           -- horário NTP do backend
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice para buscas por usuário (admin / histórico)
CREATE INDEX IF NOT EXISTS idx_report_signatures_user_id
  ON report_signatures (user_id);

-- RLS: somente o próprio usuário pode ler seus relatórios.
-- A rota /reports/verify/:id é pública (não usa Supabase diretamente, usa service_role).
ALTER TABLE report_signatures ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can read own reports"
  ON report_signatures FOR SELECT
  USING (user_id = auth.uid()::text);

-- O backend usa service_role key → bypass de RLS → pode INSERT sem policy adicional.
