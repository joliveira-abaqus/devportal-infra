# DevPortal — Infraestrutura Local

Infraestrutura de desenvolvimento local para o **DevPortal**. Orquestra serviços containerizados (PostgreSQL, Redis, LocalStack) via Docker Compose, fornecendo banco de dados, cache e emulação de serviços AWS para desenvolvimento.

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Quick Start](#quick-start)
- [Serviços e Portas](#serviços-e-portas)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Scripts](#scripts)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Ordem de Inicialização do Ecossistema](#ordem-de-inicialização-do-ecossistema)
- [Comandos Úteis](#comandos-úteis)
- [CI/CD](#cicd)
- [Repositórios Relacionados](#repositórios-relacionados)
- [Licença](#licença)

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) (>= 20.10)
- [Docker Compose](https://docs.docker.com/compose/install/) (plugin v2)

## Quick Start

### Setup automático (recomendado)

```bash
./scripts/setup-dev.sh
```

Este script:

1. Verifica se Docker e Docker Compose estão instalados
2. Sobe todos os serviços (`docker compose up -d`)
3. Aguarda cada serviço ficar _healthy_ (com health checks)
4. Popula o banco de dados com schema e dados de teste

### Setup manual

```bash
# Subir serviços
docker compose up -d

# Verificar status
docker compose ps

# Popular o banco de dados
./scripts/seed-db.sh
```

## Serviços e Portas

| Serviço | Imagem | Porta | Descrição |
|---------|--------|-------|-----------|
| PostgreSQL | `postgres:16-alpine` | 5432 | Banco de dados relacional principal |
| Redis | `redis:7-alpine` | 6379 | Cache (pattern cache-aside) e filas |
| LocalStack | `localstack/localstack:4.0` | 4566 | Emulação de serviços AWS (S3, SQS) |

### Credenciais do PostgreSQL

| Campo | Valor |
|-------|-------|
| Usuário | `devportal` |
| Senha | `devportal` |
| Database | `devportal` |
| Connection string | `postgresql://devportal:devportal@localhost:5432/devportal` |

### Recursos AWS (LocalStack)

| Recurso | Nome / URL |
|---------|------------|
| S3 Bucket | `devportal-attachments` |
| SQS Queue | `http://localhost:4566/000000000000/devportal-requests` |
| Region | `us-east-1` |
| Access Key / Secret | `test` / `test` |

### Usuário de teste

| Campo | Valor |
|-------|-------|
| Email | `dev@devportal.local` |
| Senha | `DevPortal123!` |

## Variáveis de Ambiente

Copie o arquivo de exemplo e ajuste conforme necessário:

```bash
cp .env.example .env
```

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `POSTGRES_USER` | Usuário do PostgreSQL | `devportal` |
| `POSTGRES_PASSWORD` | Senha do PostgreSQL | `devportal` |
| `POSTGRES_DB` | Nome do banco de dados | `devportal` |
| `REDIS_URL` | URL de conexão do Redis | `redis://localhost:6379` |
| `AWS_ENDPOINT` | Endpoint do LocalStack | `http://localhost:4566` |
| `AWS_REGION` | Região AWS | `us-east-1` |
| `AWS_ACCESS_KEY_ID` | Chave de acesso AWS (local) | `test` |
| `AWS_SECRET_ACCESS_KEY` | Secret de acesso AWS (local) | `test` |
| `S3_BUCKET` | Nome do bucket S3 | `devportal-attachments` |
| `SQS_QUEUE_URL` | URL da fila SQS | `http://localhost:4566/000000000000/devportal-requests` |

## Scripts

| Script | Descrição |
|--------|-----------|
| `scripts/setup-dev.sh` | Setup completo: sobe serviços, aguarda health checks e executa seed |
| `scripts/seed-db.sh` | Cria tabelas (`users`, `requests`, `request_events`) e insere dados de teste |
| `localstack/init-aws.sh` | Cria bucket S3 e fila SQS automaticamente quando o LocalStack inicia |

### Schema do Banco de Dados

O script `seed-db.sh` cria as seguintes tabelas:

- **`users`** — Cadastro de usuários (email, nome, hash de senha)
- **`requests`** — Solicitações técnicas (título, descrição, status)
- **`request_events`** — Log de eventos imutável com payload JSONB

## Estrutura do Projeto

```
devportal-infra/
├── docker-compose.yml            # Definição dos serviços (PostgreSQL, Redis, LocalStack)
├── docker-compose.override.yml   # Overrides para desenvolvimento (logging verboso, debug)
├── localstack/
│   └── init-aws.sh               # Inicialização automática de recursos AWS locais
├── scripts/
│   ├── setup-dev.sh              # Setup completo do ambiente
│   └── seed-db.sh                # Schema e dados de teste do banco
├── .github/
│   └── workflows/
│       └── ci.yml                # Pipeline de CI (validação + smoke test)
├── .env.example                  # Template de variáveis de ambiente
└── README.md                     # Esta documentação
```

## Ordem de Inicialização do Ecossistema

Os 3 repositórios do DevPortal devem ser iniciados nesta ordem:

```bash
# 1. Infraestrutura (este repositório)
cd devportal-infra && ./scripts/setup-dev.sh

# 2. Backend API
cd devportal-api && cp .env.example .env && npx prisma migrate dev && npm run dev

# 3. Frontend
cd devportal-frontend && npm run dev
```

| Serviço | Porta | Depende de |
|---------|-------|------------|
| devportal-infra | 5432, 6379, 4566 | — (independente) |
| devportal-api | 3001 | PostgreSQL, Redis, LocalStack |
| devportal-frontend | 3000 | devportal-api |

## Comandos Úteis

```bash
# Ver logs em tempo real
docker compose logs -f

# Ver logs de um serviço específico
docker compose logs -f postgres

# Verificar status dos serviços
docker compose ps

# Parar serviços (mantém dados)
docker compose down

# Parar serviços e remover volumes (apaga todos os dados)
docker compose down -v

# Re-popular o banco de dados
./scripts/seed-db.sh

# Resetar o ambiente do zero
docker compose down -v && ./scripts/setup-dev.sh
```

## CI/CD

O pipeline de CI (GitHub Actions) é executado automaticamente em push e PRs para `main`:

1. **Validação** — Sintaxe do `docker-compose.yml` e lint dos shell scripts com `shellcheck`
2. **Smoke test** — Sobe todos os serviços, verifica health checks, valida conexões (PostgreSQL, Redis), confirma recursos AWS (S3, SQS) e executa o seed do banco

## Repositórios Relacionados

| Repositório | Descrição |
|-------------|-----------|
| [devportal-api](https://github.com/joliveira-abaqus/devportal-api) | Backend Express + Prisma (porta 3001) |
| [devportal-frontend](https://github.com/joliveira-abaqus/devportal-frontend) | Frontend Next.js (porta 3000) |

## Licença

Uso interno.

---

_Originalmente escrito e mantido por contribuidores e [Devin](https://app.devin.ai), com atualizações do time principal._
