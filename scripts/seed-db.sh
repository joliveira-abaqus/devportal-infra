#!/usr/bin/env bash
# Script para popular o banco de dados com schema e dados de teste
# Executa via docker exec — não requer psql instalado no host
#
# O schema abaixo espelha prisma/schema.prisma do devportal-api (UUID como PK,
# author_id em requests). Se a API já aplicou as migrations Prisma, os
# CREATE TABLE IF NOT EXISTS são ignorados e apenas o usuário de teste é criado.

set -euo pipefail

CONTAINER="${POSTGRES_CONTAINER:-devportal-postgres}"
PGUSER="${PGUSER:-devportal}"
PGDATABASE="${PGDATABASE:-devportal}"

echo "==> Conectando ao PostgreSQL no container ${CONTAINER}..."

# Bancos criados por versões antigas deste script têm users.id BIGSERIAL e
# requests.user_id; os CREATE TABLE IF NOT EXISTS abaixo seriam ignorados e o
# resto do script falharia de forma difícil de diagnosticar.
legacy=$(docker exec -i "$CONTAINER" psql -tAX -U "$PGUSER" -d "$PGDATABASE" -c \
    "SELECT 1 FROM information_schema.columns
     WHERE table_name = 'requests' AND column_name = 'user_id'")

if [ -n "$legacy" ]; then
    echo "ERRO: o banco '${PGDATABASE}' tem o schema antigo (requests.user_id)," >&2
    echo "      incompatível com o schema atual (requests.author_id)." >&2
    echo "      Recrie o volume: docker compose down -v && ./scripts/setup-dev.sh" >&2
    exit 1
fi

docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$PGUSER" -d "$PGDATABASE" <<'SQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Tabela de usuários
CREATE TABLE IF NOT EXISTS users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) NOT NULL UNIQUE,
    name          VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Tabela de requisições
CREATE TABLE IF NOT EXISTS requests (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id     UUID         NOT NULL REFERENCES users(id),
    title         VARCHAR(255) NOT NULL,
    description   TEXT         NOT NULL,
    type          VARCHAR(50)  NOT NULL,
    status        VARCHAR(50)  NOT NULL DEFAULT 'pending',
    pr_url        VARCHAR(500),
    attachment_s3 VARCHAR(500),
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Tabela de eventos de requisição
CREATE TABLE IF NOT EXISTS request_events (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id  UUID         NOT NULL REFERENCES requests(id),
    event_type  VARCHAR(100) NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_requests_author_id ON requests(author_id);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_request_events_request_id ON request_events(request_id);

-- Usuário de teste
-- Senha: DevPortal123! (bcrypt hash)
INSERT INTO users (id, email, name, password_hash)
VALUES (
    gen_random_uuid(),
    'dev@devportal.local',
    'Dev User',
    '$2b$10$rjN9E7P0rombOVtOhFryuOVciZSvb.OI8SLfmFdqlFpyHeRCig3cq'
)
ON CONFLICT (email) DO NOTHING;

SQL

echo "==> Banco de dados populado com sucesso!"
