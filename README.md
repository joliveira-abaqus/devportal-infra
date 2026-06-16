# DevPortal — Infraestrutura Local de Desenvolvimento

Orquestra a infraestrutura local de desenvolvimento e pipeline de CI para a aplicação DevPortal, fornecendo serviços containerizados de banco de dados, cache e emulação de cloud AWS.

---

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Quick Start](#quick-start)
- [Serviços](#serviços)
  - [PostgreSQL](#postgresql)
  - [Redis](#redis)
  - [LocalStack (AWS S3/SQS)](#localstack-aws-s3sqs)
- [Scripts](#scripts)
  - [setup-dev.sh](#setup-devsh)
  - [seed-db.sh](#seed-dbsh)
  - [init-aws.sh](#init-awssh)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Arquitetura](#arquitetura)
  - [Diagrama de Serviços](#diagrama-de-serviços)
  - [Modelo de Dados](#modelo-de-dados)
- [CI/CD](#cicd)
- [Comandos Úteis](#comandos-úteis)
- [Troubleshooting](#troubleshooting)
- [Contribuição](#contribuição)
- [Licença](#licença)

---

## Pré-requisitos

| Ferramenta       | Versão mínima | Instalação                                        |
|------------------|---------------|---------------------------------------------------|
| Docker           | >= 20.10      | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| Docker Compose   | v2 (plugin)   | Incluído no Docker Desktop; Linux: [plugin install](https://docs.docker.com/compose/install/linux/) |

Verifique se ambos estão instalados:

```bash
docker --version
docker compose version
```

---

## Quick Start

```bash
# 1. Clone o repositório
git clone https://github.com/joliveira-abaqus/devportal-infra.git
cd devportal-infra

# 2. Copie as variáveis de ambiente
cp .env.example .env

# 3. Suba toda a infraestrutura (serviços + seed do banco)
./scripts/setup-dev.sh
```

Ao final, todos os serviços estarão prontos:

| Serviço      | Endereço              |
|--------------|-----------------------|
| PostgreSQL   | `localhost:5432`      |
| Redis        | `localhost:6379`      |
| LocalStack   | `localhost:4566`      |

**Usuário de teste pré-cadastrado:**

| Campo | Valor                 |
|-------|-----------------------|
| Email | `dev@devportal.local` |
| Senha | `DevPortal123!`       |

> **Dica:** Este repositório é o primeiro a ser iniciado no ecossistema DevPortal. Após subir a infra, inicie o [devportal-api](https://github.com/joliveira-abaqus/devportal-api) (`:3001`) e depois o [devportal-frontend](https://github.com/joliveira-abaqus/devportal-frontend) (`:3000`).

---

## Serviços

### PostgreSQL

| Propriedade     | Valor                                                          |
|-----------------|----------------------------------------------------------------|
| Imagem          | `postgres:16-alpine`                                           |
| Container       | `devportal-postgres`                                           |
| Porta           | `5432`                                                         |
| Usuário / Senha | `devportal` / `devportal`                                      |
| Database        | `devportal`                                                    |
| Volume          | `pgdata` — persistência dos dados em `/var/lib/postgresql/data`|
| Health-check    | `pg_isready -U devportal -d devportal` (5s intervalo, 5 retries) |
| Connection string | `postgresql://devportal:devportal@localhost:5432/devportal`  |

No ambiente de desenvolvimento local (`docker-compose.override.yml`), o PostgreSQL é configurado com logging verboso:

```
log_statement=all, log_connections=on
```

### Redis

| Propriedade  | Valor                          |
|--------------|--------------------------------|
| Imagem       | `redis:7-alpine`               |
| Container    | `devportal-redis`              |
| Porta        | `6379`                         |
| URL          | `redis://localhost:6379`       |
| Health-check | `redis-cli ping` (5s intervalo, 5 retries) |

Utilizado como cache (padrão cache-aside) e suporte a filas pela API. No override local, o Redis roda com `--loglevel verbose`.

### LocalStack (AWS S3/SQS)

| Propriedade  | Valor                                                              |
|--------------|--------------------------------------------------------------------|
| Imagem       | `localstack/localstack:4.0`                                        |
| Container    | `devportal-localstack`                                             |
| Porta        | `4566`                                                             |
| Serviços AWS | S3, SQS                                                            |
| Região       | `us-east-1`                                                        |
| Credenciais  | Access Key: `test` / Secret Key: `test`                            |
| Health-check | `curl -f http://localhost:4566/_localstack/health` (10s intervalo, 5 retries) |

Recursos provisionados automaticamente ao iniciar:

| Recurso   | Nome / URL                                                     |
|-----------|----------------------------------------------------------------|
| S3 Bucket | `devportal-attachments` — armazenamento de anexos              |
| SQS Queue | `http://localhost:4566/000000000000/devportal-requests` — fila de processamento assíncrono |

No override local, o LocalStack opera com `DEBUG=1` e `LS_LOG=trace`.

---

## Scripts

### `setup-dev.sh`

**Caminho:** `scripts/setup-dev.sh`

Script principal de inicialização do ambiente. Executa as seguintes etapas:

1. Verifica se Docker e Docker Compose estão instalados
2. Sobe todos os serviços via `docker compose up -d`
3. Aguarda cada serviço reportar status `healthy` (polling com até 30 tentativas, intervalo de 2s)
4. Executa o seed do banco de dados (`seed-db.sh`)
5. Exibe resumo com endereços e credenciais

```bash
./scripts/setup-dev.sh
```

### `seed-db.sh`

**Caminho:** `scripts/seed-db.sh`

Cria o schema do banco de dados e insere dados de teste. Executa via `docker exec` — **não requer** `psql` instalado no host.

**Tabelas criadas:**

| Tabela           | Descrição                                  |
|------------------|--------------------------------------------|
| `users`          | Usuários do sistema (email, name, password_hash) |
| `requests`       | Requisições/tickets (title, description, status) |
| `request_events` | Log imutável de eventos com payload JSONB  |

**Índices criados:**

| Índice                              | Coluna(s)              |
|-------------------------------------|------------------------|
| `idx_requests_user_id`              | `requests(user_id)`    |
| `idx_requests_status`               | `requests(status)`     |
| `idx_request_events_request_id`     | `request_events(request_id)` |

**Dados de teste:** Usuário `dev@devportal.local` / `DevPortal123!` (hash bcrypt).

```bash
./scripts/seed-db.sh
```

> O script é idempotente — usa `CREATE TABLE IF NOT EXISTS` e `ON CONFLICT DO NOTHING`.

### `init-aws.sh`

**Caminho:** `localstack/init-aws.sh`

Executado automaticamente pelo LocalStack ao atingir o estado `ready`. Provisiona os recursos AWS locais usando a CLI `awslocal`:

1. Cria o bucket S3 `devportal-attachments`
2. Cria a fila SQS `devportal-requests`
3. Lista os recursos criados para confirmação

---

## Variáveis de Ambiente

Baseado no arquivo `.env.example`. Copie e ajuste conforme necessário:

```bash
cp .env.example .env
```

| Variável                 | Valor padrão                                                 | Descrição                              |
|--------------------------|--------------------------------------------------------------|----------------------------------------|
| `POSTGRES_USER`          | `devportal`                                                  | Usuário do PostgreSQL                  |
| `POSTGRES_PASSWORD`      | `devportal`                                                  | Senha do PostgreSQL                    |
| `POSTGRES_DB`            | `devportal`                                                  | Nome do banco de dados                 |
| `REDIS_URL`              | `redis://localhost:6379`                                     | URL de conexão do Redis                |
| `AWS_ENDPOINT`           | `http://localhost:4566`                                      | Endpoint do LocalStack                 |
| `AWS_REGION`             | `us-east-1`                                                  | Região AWS simulada                    |
| `AWS_ACCESS_KEY_ID`      | `test`                                                       | Chave de acesso AWS (LocalStack)       |
| `AWS_SECRET_ACCESS_KEY`  | `test`                                                       | Chave secreta AWS (LocalStack)         |
| `S3_BUCKET`              | `devportal-attachments`                                      | Nome do bucket S3                      |
| `SQS_QUEUE_URL`          | `http://localhost:4566/000000000000/devportal-requests`      | URL da fila SQS                        |

> Seguindo o princípio [12-Factor App](https://12factor.net/config), todas as configurações são externalizadas via variáveis de ambiente.

---

## Arquitetura

### Diagrama de Serviços

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Network                    │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐ │
│  │  PostgreSQL   │  │    Redis     │  │    LocalStack     │ │
│  │  :5432        │  │  :6379       │  │    :4566          │ │
│  │              │  │              │  │                   │ │
│  │  devportal   │  │  cache-aside │  │  ┌─────────────┐ │ │
│  │  database    │  │  pattern     │  │  │ S3 Bucket   │ │ │
│  │              │  │              │  │  │ attachments │ │ │
│  │  ┌────────┐  │  │              │  │  ├─────────────┤ │ │
│  │  │ users  │  │  │              │  │  │ SQS Queue   │ │ │
│  │  │requests│  │  │              │  │  │ requests    │ │ │
│  │  │ events │  │  │              │  │  └─────────────┘ │ │
│  │  └────────┘  │  │              │  │                   │ │
│  │  vol: pgdata │  │              │  │                   │ │
│  └──────────────┘  └──────────────┘  └───────────────────┘ │
└─────────────────────────────────────────────────────────────┘
         ▲                   ▲                   ▲
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                   ┌─────────────────┐
                   │  devportal-api  │
                   │  :3001          │
                   └────────┬────────┘
                            │
                   ┌─────────────────┐
                   │devportal-frontend│
                   │  :3000          │
                   └─────────────────┘
```

**Fluxo de dependências:**

1. **devportal-infra** (este repositório) — sobe PostgreSQL, Redis e LocalStack
2. **devportal-api** — conecta aos três serviços de infra para persistência, cache e integração AWS
3. **devportal-frontend** — consome a API REST do backend

### Modelo de Dados

```
┌──────────┐       ┌──────────────┐       ┌─────────────────┐
│  users   │ 1───N │   requests   │ 1───N │ request_events  │
├──────────┤       ├──────────────┤       ├─────────────────┤
│ id (PK)  │       │ id (PK)      │       │ id (PK)         │
│ email    │       │ user_id (FK) │       │ request_id (FK) │
│ name     │       │ title        │       │ event_type      │
│ password │       │ description  │       │ payload (JSONB) │
│ created  │       │ status       │       │ created_at      │
│ updated  │       │ created_at   │       └─────────────────┘
└──────────┘       │ updated_at   │
                   └──────────────┘
```

---

## CI/CD

O pipeline de CI é definido em `.github/workflows/ci.yml` e é executado automaticamente em **push** e **pull request** para a branch `main`.

### Job 1: `validate` — Validação de configuração e scripts

| Etapa               | Comando                                         |
|----------------------|-------------------------------------------------|
| Sintaxe do Compose   | `docker compose config --quiet`                 |
| Lint dos scripts     | `shellcheck` em `init-aws.sh`, `seed-db.sh`, `setup-dev.sh` |

### Job 2: `smoke-test` — Teste de fumaça dos serviços

Executado **após** a validação (`needs: validate`):

1. Sobe todos os serviços com `docker compose up -d`
2. Aguarda PostgreSQL, Redis e LocalStack ficarem `healthy` (polling até 30 tentativas)
3. Verifica conexão com PostgreSQL (`pg_isready`)
4. Verifica conexão com Redis (`redis-cli ping`)
5. Verifica existência do bucket S3 `devportal-attachments`
6. Verifica existência da fila SQS `devportal-requests`
7. Executa o seed do banco de dados
8. Verifica que o usuário de teste `dev@devportal.local` foi criado
9. Derruba os serviços e remove volumes (`docker compose down -v`)

---

## Comandos Úteis

```bash
# Subir toda a infraestrutura (recomendado)
./scripts/setup-dev.sh

# Subir serviços manualmente
docker compose up -d

# Ver logs em tempo real
docker compose logs -f

# Ver logs de um serviço específico
docker compose logs -f postgres

# Verificar status dos serviços
docker compose ps

# Re-popular o banco de dados
./scripts/seed-db.sh

# Parar serviços (mantém dados)
docker compose down

# Parar serviços e remover todos os volumes (reset completo)
docker compose down -v

# Acessar o PostgreSQL via psql
docker exec -it devportal-postgres psql -U devportal -d devportal

# Testar conexão com Redis
docker exec -it devportal-redis redis-cli ping

# Listar buckets S3 no LocalStack
docker exec devportal-localstack awslocal s3 ls

# Listar filas SQS no LocalStack
docker exec devportal-localstack awslocal sqs list-queues
```

---

## Troubleshooting

### Porta já está em uso

```
Error: bind: address already in use
```

**Solução:** Verifique qual processo está usando a porta e encerre-o:

```bash
# Verificar porta 5432 (PostgreSQL)
lsof -i :5432
# ou
sudo ss -tlnp | grep 5432

# Encerrar o processo ou alterar a porta no docker-compose.override.yml
```

### Container não fica healthy

```
ERROR: postgres não ficou healthy após 60s
```

**Solução:**

1. Verifique os logs do container:
   ```bash
   docker compose logs postgres
   ```
2. Verifique se há espaço em disco:
   ```bash
   docker system df
   ```
3. Recrie os containers do zero:
   ```bash
   docker compose down -v
   docker compose up -d
   ```

### LocalStack não provisiona os recursos AWS

**Solução:**

1. Verifique se o script tem permissão de execução:
   ```bash
   chmod +x localstack/init-aws.sh
   ```
2. Verifique os logs do LocalStack:
   ```bash
   docker compose logs localstack
   ```
3. Provisione manualmente:
   ```bash
   docker exec devportal-localstack awslocal s3 mb s3://devportal-attachments
   docker exec devportal-localstack awslocal sqs create-queue --queue-name devportal-requests
   ```

### Seed do banco falha com "connection refused"

**Solução:** O PostgreSQL pode ainda não estar pronto. Use o script `setup-dev.sh`, que aguarda o health-check antes de executar o seed. Para rodar manualmente, verifique primeiro:

```bash
docker exec devportal-postgres pg_isready -U devportal -d devportal
```

### Docker Compose não reconhece o comando

```
docker: 'compose' is not a docker command.
```

**Solução:** Você está usando uma versão antiga do Docker. Instale o plugin Docker Compose v2:

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install docker-compose-plugin
```

---

## Contribuição

1. Faça um fork do repositório
2. Crie uma branch a partir de `main`:
   ```bash
   git checkout -b feature/minha-alteracao
   ```
3. Faça suas alterações seguindo as convenções do projeto
4. Valide localmente:
   ```bash
   docker compose config --quiet
   shellcheck scripts/*.sh localstack/init-aws.sh
   ```
5. Commit com mensagem descritiva em português:
   ```bash
   git commit -m "feat: adicionar novo serviço de mensageria"
   ```
6. Abra um Pull Request para `main`

### Convenções

- **Branches:** `feature/<escopo-da-alteracao>` (kebab-case)
- **Commits:** mensagens em português (BR)
- **Scripts:** devem passar no `shellcheck` sem warnings
- **Docker Compose:** configuração validada via `docker compose config --quiet`

---

## Licença

Este projeto é de uso interno. Consulte o time responsável para informações sobre licenciamento.

---

_Originally written and maintained by contributors and [Devin](https://app.devin.ai), with updates from the core team._
