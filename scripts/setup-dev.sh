#!/usr/bin/env bash
# Script de setup do ambiente de desenvolvimento local

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sem cor

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# 1. Verificar se Docker está instalado
info "Verificando pré-requisitos..."
if ! command -v docker &>/dev/null; then
    error "Docker não está instalado. Instale o Docker antes de continuar: https://docs.docker.com/get-docker/"
fi

if ! docker compose version &>/dev/null; then
    error "Docker Compose (plugin) não está disponível. Verifique sua instalação do Docker."
fi

info "Docker e Docker Compose encontrados."

# 2. Subir serviços
info "Subindo serviços com docker compose..."
cd "$PROJECT_DIR"
docker compose up -d

# 3. Esperar serviços ficarem healthy
info "Aguardando serviços ficarem healthy..."

MAX_RETRIES=30
RETRY_INTERVAL=2

wait_for_healthy() {
    local service="$1"
    local retries=0

    while [ $retries -lt $MAX_RETRIES ]; do
        status=$(docker inspect --format='{{.State.Health.Status}}' "devportal-${service}" 2>/dev/null || echo "not_found")

        if [ "$status" = "healthy" ]; then
            info "${service} está healthy!"
            return 0
        fi

        retries=$((retries + 1))
        warn "${service}: aguardando... (${retries}/${MAX_RETRIES}) - status: ${status}"
        sleep "$RETRY_INTERVAL"
    done

    error "${service} não ficou healthy após $((MAX_RETRIES * RETRY_INTERVAL))s"
}

wait_for_healthy "postgres"
wait_for_healthy "redis"
wait_for_healthy "localstack"

# 4. Rodar seed do banco de dados
info "Executando seed do banco de dados..."
"$SCRIPT_DIR/seed-db.sh"

# 5. Mensagem de sucesso
echo ""
echo "============================================="
echo -e "${GREEN}  Ambiente de desenvolvimento pronto!${NC}"
echo "============================================="
echo ""
echo "  Serviços disponíveis:"
echo "  ─────────────────────────────────────────"
echo "  PostgreSQL : localhost:5432  (user: devportal / pass: devportal)"
echo "  Redis      : localhost:6379"
echo "  LocalStack : localhost:4566"
echo "  S3 Bucket  : devportal-attachments"
echo "  SQS Queue  : devportal-requests"
echo ""
echo "  Usuário de teste:"
echo "  Email: dev@devportal.local"
echo "  Senha: DevPortal123!"
echo ""
echo "  Comandos úteis:"
echo "  docker compose logs -f         # Ver logs"
echo "  docker compose down            # Parar serviços"
echo "  docker compose down -v         # Parar e remover volumes"
echo "  ./scripts/seed-db.sh           # Re-popular o banco"
echo "============================================="
