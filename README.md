# DevPortal Infra

Ambiente de infraestrutura local containerizado para o **DevPortal**, orquestrando banco de dados, cache e servicos AWS emulados via Docker Compose.

[![CI](https://github.com/joliveira-abaqus/devportal-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/joliveira-abaqus/devportal-infra/actions/workflows/ci.yml)

---

## Sumario

- [Pre-requisitos](#pre-requisitos)
- [Quick Start](#quick-start)
- [Servicos e Portas](#servicos-e-portas)
- [Variaveis de Ambiente](#variaveis-de-ambiente)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [CI/CD](#cicd)
- [Comandos Uteis](#comandos-uteis)
- [Repositorios Relacionados](#repositorios-relacionados)
- [Contribuicao](#contribuicao)
- [Licenca](#licenca)

---

## Pre-requisitos

| Ferramenta      | Versao minima | Link                                           |
|-----------------|---------------|-------------------------------------------------|
| Docker          | >= 20.10      | [Instalar](https://docs.docker.com/get-docker/) |
| Docker Compose  | v2 (plugin)   | [Instalar](https://docs.docker.com/compose/install/) |

> **Nota:** o Docker Compose deve estar disponivel como plugin (`docker compose`), e nao como binario standalone (`docker-compose`).

---

## Quick Start

### Setup automatico (recomendado)

```bash
# Clonar o repositorio
git clone https://github.com/joliveira-abaqus/devportal-infra.git
cd devportal-infra

# Copiar variaveis de ambiente
cp .env.example .env

# Subir tudo com um unico comando
./scripts/setup-dev.sh
```

O script `setup-dev.sh` executa os seguintes passos:

1. Verifica se Docker e Docker Compose estao instalados
2. Sobe todos os servicos via `docker compose up -d`
3. Aguarda cada servico atingir o status **healthy**
4. Popula o banco de dados com schema e dados de teste

### Setup manual

```bash
# Subir servicos
docker compose up -d

# Verificar status dos containers
docker compose ps

# Popular o banco de dados
./scripts/seed-db.sh
```

---

## Servicos e Portas

| Servico     | Porta  | Imagem                     | Descricao                           |
|-------------|--------|----------------------------|-------------------------------------|
| PostgreSQL  | 5432   | `postgres:16-alpine`       | Banco de dados relacional principal |
| Redis       | 6379   | `redis:7-alpine`           | Cache e gerenciamento de filas      |
| LocalStack  | 4566   | `localstack/localstack:4.0`| Emulacao de servicos AWS (S3, SQS)  |

### Credenciais do PostgreSQL

| Campo    | Valor       |
|----------|-------------|
| Usuario  | `devportal` |
| Senha    | `devportal` |
| Database | `devportal` |

### Recursos AWS (LocalStack)

| Recurso   | Nome / URL                                                |
|-----------|-----------------------------------------------------------|
| S3 Bucket | `devportal-attachments`                                   |
| SQS Queue | `http://localhost:4566/000000000000/devportal-requests`   |

### Usuario de teste

| Campo | Valor                 |
|-------|-----------------------|
| Email | `dev@devportal.local` |
| Senha | `DevPortal123!`       |

---

## Variaveis de Ambiente

Copie o template e ajuste conforme necessario:

```bash
cp .env.example .env
```

| Variavel                 | Valor padrao                                              | Descricao                        |
|--------------------------|-----------------------------------------------------------|----------------------------------|
| `POSTGRES_USER`          | `devportal`                                               | Usuario do PostgreSQL            |
| `POSTGRES_PASSWORD`      | `devportal`                                               | Senha do PostgreSQL              |
| `POSTGRES_DB`            | `devportal`                                               | Nome do banco de dados           |
| `REDIS_URL`              | `redis://localhost:6379`                                  | URL de conexao do Redis          |
| `AWS_ENDPOINT`           | `http://localhost:4566`                                   | Endpoint do LocalStack           |
| `AWS_REGION`             | `us-east-1`                                               | Regiao AWS emulada               |
| `AWS_ACCESS_KEY_ID`      | `test`                                                    | Chave de acesso (LocalStack)     |
| `AWS_SECRET_ACCESS_KEY`  | `test`                                                    | Chave secreta (LocalStack)       |
| `S3_BUCKET`              | `devportal-attachments`                                   | Nome do bucket S3                |
| `SQS_QUEUE_URL`          | `http://localhost:4566/000000000000/devportal-requests`   | URL da fila SQS                  |

---

## Estrutura do Projeto

```
devportal-infra/
├── docker-compose.yml            # Definicao e orquestracao dos servicos
├── docker-compose.override.yml   # Overrides de debug/logging para dev local
├── localstack/
│   └── init-aws.sh               # Provisionamento de bucket S3 e fila SQS
├── scripts/
│   ├── setup-dev.sh              # Bootstrap completo do ambiente
│   └── seed-db.sh                # Criacao de schema e dados de teste
├── .github/
│   └── workflows/
│       └── ci.yml                # Pipeline de CI (GitHub Actions)
├── .env.example                  # Template de variaveis de ambiente
├── .gitignore                    # Arquivos ignorados pelo Git
└── README.md                     # Esta documentacao
```

### Descricao dos componentes principais

- **`docker-compose.yml`** — Define os tres servicos (PostgreSQL, Redis, LocalStack) com health checks e volumes persistentes.
- **`docker-compose.override.yml`** — Ativa logging verboso e debug para desenvolvimento local. Carregado automaticamente pelo Docker Compose.
- **`localstack/init-aws.sh`** — Executado automaticamente quando o LocalStack atinge o status *ready*. Cria o bucket S3 `devportal-attachments` e a fila SQS `devportal-requests`.
- **`scripts/setup-dev.sh`** — Script principal de bootstrap. Verifica pre-requisitos, sobe servicos, aguarda health checks e executa o seed.
- **`scripts/seed-db.sh`** — Cria as tabelas `users`, `requests` e `request_events` e insere um usuario de teste. Executa via `docker exec`, sem necessidade de `psql` no host.

---

## CI/CD

O pipeline de CI roda automaticamente via **GitHub Actions** em push e pull requests para `main`. Ele possui dois jobs:

### `validate`
- Valida a sintaxe do `docker-compose.yml` com `docker compose config`
- Executa `shellcheck` em todos os shell scripts

### `smoke-test`
- Sobe todos os servicos com `docker compose up -d`
- Aguarda cada container atingir status **healthy**
- Verifica conectividade com PostgreSQL, Redis e LocalStack
- Confirma que o bucket S3 e a fila SQS foram provisionados
- Executa o seed e valida que o usuario de teste foi inserido

---

## Comandos Uteis

```bash
# Ver logs de todos os servicos em tempo real
docker compose logs -f

# Ver logs de um servico especifico
docker compose logs -f postgres

# Parar todos os servicos
docker compose down

# Parar servicos e remover volumes (reset completo)
docker compose down -v

# Re-popular o banco de dados
./scripts/seed-db.sh

# Acessar o PostgreSQL via psql dentro do container
docker exec -it devportal-postgres psql -U devportal -d devportal

# Testar conectividade do Redis
docker exec devportal-redis redis-cli ping

# Listar buckets S3 no LocalStack
docker exec devportal-localstack awslocal s3 ls

# Listar filas SQS no LocalStack
docker exec devportal-localstack awslocal sqs list-queues
```

---

## Repositorios Relacionados

| Repositorio | Descricao |
|-------------|-----------|
| [devportal-api](https://github.com/joliveira-abaqus/devportal-api) | Backend API (Node.js, Express, Prisma) |
| [devportal-frontend](https://github.com/joliveira-abaqus/devportal-frontend) | Frontend (React, Next.js 14) |

---

## Contribuicao

Contribuicoes sao bem-vindas! Para colaborar:

1. Crie uma branch a partir de `main` usando o prefixo `feature/` (ex.: `feature/adicionar-servico-x`)
2. Faca suas alteracoes e valide localmente:
   ```bash
   docker compose config --quiet
   shellcheck localstack/init-aws.sh scripts/seed-db.sh scripts/setup-dev.sh
   ```
3. Abra um Pull Request para `main`

> Mensagens de commit, comentarios no codigo e descricoes de PR devem ser escritos em **portugues (BR)**.

---

## Licenca

Este projeto e de uso interno. Consulte a equipe responsavel para informacoes sobre licenciamento.

---

_Originally written and maintained by contributors and [Devin](https://app.devin.ai), with updates from the core team._
