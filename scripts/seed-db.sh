#!/usr/bin/env bash
# Script para popular o banco de dados com schema e dados de teste

set -euo pipefail

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-devportal}"
PGPASSWORD="${PGPASSWORD:-devportal}"
PGDATABASE="${PGDATABASE:-devportal}"

export PGPASSWORD

echo "==> Conectando ao PostgreSQL em ${PGHOST}:${PGPORT}..."

psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" <<'SQL'
-- Tabela de usuários
CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL    PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    name          VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Tabela de requisições
CREATE TABLE IF NOT EXISTS requests (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES users(id),
    title       VARCHAR(255) NOT NULL,
    description TEXT,
    status      VARCHAR(50)  NOT NULL DEFAULT 'PENDING',
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Tabela de eventos de requisição
CREATE TABLE IF NOT EXISTS request_events (
    id          BIGSERIAL    PRIMARY KEY,
    request_id  BIGINT       NOT NULL REFERENCES requests(id),
    event_type  VARCHAR(100) NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_requests_user_id ON requests(user_id);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_request_events_request_id ON request_events(request_id);

-- Usuário de teste
-- Senha: DevPortal123! (bcrypt hash)
INSERT INTO users (email, name, password_hash)
VALUES (
    'dev@devportal.local',
    'Dev User',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy'
)
ON CONFLICT (email) DO NOTHING;

SQL

echo "==> Banco de dados populado com sucesso!"
