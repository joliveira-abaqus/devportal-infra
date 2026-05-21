# DevPortal — Infraestrutura Local

[![CI](https://github.com/joliveira-abaqus/devportal-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/joliveira-abaqus/devportal-infra/actions/workflows/ci.yml)

Containerized local development infrastructure for the **DevPortal** platform — spins up PostgreSQL, Redis, and LocalStack (AWS S3/SQS) with a single command so developers can work on the [API](https://github.com/joliveira-abaqus/devportal-api) and [Frontend](https://github.com/joliveira-abaqus/devportal-frontend) without external dependencies.

---

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Services and Ports](#services-and-ports)
- [Environment Variables](#environment-variables)
- [Database Schema](#database-schema)
- [Project Structure](#project-structure)
- [Common Tasks](#common-tasks)
- [CI Pipeline](#ci-pipeline)
- [Troubleshooting](#troubleshooting)
- [Related Repositories](#related-repositories)
- [Contributing](#contributing)
- [License](#license)

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   Host Machine                           │
│                                                          │
│  ┌──────────────┐  ┌──────────┐  ┌────────────────────┐ │
│  │  PostgreSQL   │  │  Redis   │  │    LocalStack      │ │
│  │  :5432        │  │  :6379   │  │    :4566           │ │
│  │               │  │          │  │  ┌──────┐ ┌─────┐  │ │
│  │  devportal db │  │  cache   │  │  │  S3  │ │ SQS │  │ │
│  └──────────────┘  └──────────┘  │  └──────┘ └─────┘  │ │
│                                  └────────────────────┘ │
│                                                          │
│      ▲                ▲                  ▲               │
│      └────────────────┴──────────────────┘               │
│                devportal-api / devportal-frontend         │
└──────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Tool             | Version  | Install                                                      |
|------------------|----------|--------------------------------------------------------------|
| Docker           | >= 20.10 | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| Docker Compose   | v2 (plugin) | Included with Docker Desktop; on Linux see [Compose plugin](https://docs.docker.com/compose/install/linux/) |

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/joliveira-abaqus/devportal-infra.git
cd devportal-infra

# 2. (Optional) Create a local .env from the template
cp .env.example .env

# 3. Start everything — services, health checks, and seed data
./scripts/setup-dev.sh
```

The `setup-dev.sh` script:

1. Checks that Docker and Docker Compose are installed.
2. Starts all containers via `docker compose up -d`.
3. Polls each container until its health check passes.
4. Runs `seed-db.sh` to create the schema and insert test data.

### Manual Setup

If you prefer to run each step yourself:

```bash
docker compose up -d          # Start containers
docker compose ps             # Verify status
./scripts/seed-db.sh          # Create schema and seed data
```

---

## Services and Ports

| Service      | Container              | Port   | Description                               |
|--------------|------------------------|--------|-------------------------------------------|
| PostgreSQL 16| `devportal-postgres`   | `5432` | Primary relational database               |
| Redis 7      | `devportal-redis`      | `6379` | Cache (cache-aside pattern) and pub/sub   |
| LocalStack 4 | `devportal-localstack` | `4566` | AWS emulation — S3 and SQS                |

### Credentials

| Service    | User        | Password    | Database    |
|------------|-------------|-------------|-------------|
| PostgreSQL | `devportal` | `devportal` | `devportal` |

### AWS Resources (LocalStack)

| Resource  | Name / URL                                              |
|-----------|---------------------------------------------------------|
| S3 Bucket | `devportal-attachments`                                 |
| SQS Queue | `http://localhost:4566/000000000000/devportal-requests` |

### Test User

| Field    | Value                 |
|----------|-----------------------|
| Email    | `dev@devportal.local` |
| Password | `DevPortal123!`       |

---

## Environment Variables

Copy the template and adjust if needed:

```bash
cp .env.example .env
```

| Variable                 | Default                                                  | Description                        |
|--------------------------|----------------------------------------------------------|------------------------------------|
| `POSTGRES_USER`          | `devportal`                                              | PostgreSQL user                    |
| `POSTGRES_PASSWORD`      | `devportal`                                              | PostgreSQL password                |
| `POSTGRES_DB`            | `devportal`                                              | PostgreSQL database name           |
| `REDIS_URL`              | `redis://localhost:6379`                                 | Redis connection string            |
| `AWS_ENDPOINT`           | `http://localhost:4566`                                  | LocalStack endpoint                |
| `AWS_REGION`             | `us-east-1`                                              | AWS region for LocalStack          |
| `AWS_ACCESS_KEY_ID`      | `test`                                                   | Dummy credential for LocalStack    |
| `AWS_SECRET_ACCESS_KEY`  | `test`                                                   | Dummy credential for LocalStack    |
| `S3_BUCKET`              | `devportal-attachments`                                  | S3 bucket name                     |
| `SQS_QUEUE_URL`          | `http://localhost:4566/000000000000/devportal-requests`  | SQS queue URL                      |

---

## Database Schema

The seed script (`scripts/seed-db.sh`) creates the following tables:

| Table              | Purpose                                          |
|--------------------|--------------------------------------------------|
| `users`            | User accounts (email, name, bcrypt password hash) |
| `requests`         | Task/bug/feature tickets linked to a user        |
| `request_events`   | Immutable audit log with JSONB payloads          |

Key indexes: `idx_requests_user_id`, `idx_requests_status`, `idx_request_events_request_id`.

All DDL statements are idempotent (`CREATE TABLE IF NOT EXISTS`, `ON CONFLICT DO NOTHING`), so the seed script is safe to re-run at any time.

---

## Project Structure

```
devportal-infra/
├── docker-compose.yml            # Service definitions (Postgres, Redis, LocalStack)
├── docker-compose.override.yml   # Local dev overrides (verbose logging, debug flags)
├── localstack/
│   └── init-aws.sh               # Auto-provisions S3 bucket and SQS queue on startup
├── scripts/
│   ├── setup-dev.sh              # One-command environment bootstrap
│   └── seed-db.sh                # Schema creation and test data insertion
├── .env.example                  # Template for required environment variables
├── .github/
│   └── workflows/
│       └── ci.yml                # GitHub Actions CI pipeline
├── .gitignore
└── README.md
```

### Docker Compose Override

`docker-compose.override.yml` is automatically merged by Docker Compose during local development and enables:

- **PostgreSQL**: verbose query logging (`log_statement=all`, `log_connections=on`).
- **Redis**: `--loglevel verbose`.
- **LocalStack**: `DEBUG=1` and `LS_LOG=trace`.

This file is **not** used in CI — the pipeline runs only `docker-compose.yml`.

---

## Common Tasks

```bash
# View live logs for all services
docker compose logs -f

# View logs for a single service
docker compose logs -f postgres

# Stop services (data persists in Docker volume)
docker compose down

# Stop services AND destroy all data
docker compose down -v

# Re-seed the database without restarting containers
./scripts/seed-db.sh

# Full reset — wipe and rebuild from scratch
docker compose down -v && ./scripts/setup-dev.sh
```

---

## CI Pipeline

The [GitHub Actions workflow](.github/workflows/ci.yml) runs on every push and pull request to `main`:

| Job           | Steps                                                                 |
|---------------|-----------------------------------------------------------------------|
| **validate**  | Verify `docker-compose.yml` syntax; lint all shell scripts with [ShellCheck](https://www.shellcheck.net/) |
| **smoke-test**| Start services, wait for health checks, verify connectivity (pg_isready, redis-cli ping), confirm S3 bucket and SQS queue exist, run seed, assert test user was created, then tear down |

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Port `5432`/`6379`/`4566` already in use | Another service occupies the port | Stop the conflicting process or change the port mapping in `docker-compose.override.yml` |
| `setup-dev.sh` fails with "not healthy" | Container starts slowly or crashes | Run `docker compose logs <service>` to check for errors |
| `seed-db.sh` connection refused | PostgreSQL not ready yet | Wait for the health check or run `docker compose ps` to confirm the container is healthy |
| LocalStack resources missing | `init-aws.sh` didn't execute | Verify the script is executable (`chmod +x localstack/init-aws.sh`) and restart: `docker compose restart localstack` |

---

## Related Repositories

| Repository | Description |
|------------|-------------|
| [devportal-api](https://github.com/joliveira-abaqus/devportal-api) | Backend API — Express, Prisma, PostgreSQL, Redis, AWS S3/SQS |
| [devportal-frontend](https://github.com/joliveira-abaqus/devportal-frontend) | Frontend — Next.js 14, React, Tailwind CSS, NextAuth.js |

Both repositories expect the services from this infra repo to be running locally.

---

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feat/my-change`).
3. Follow the project's [shell script conventions](#shell-script-conventions) below.
4. Make sure CI passes: `docker compose config --quiet && shellcheck scripts/*.sh localstack/init-aws.sh`.
5. Open a pull request targeting `main`.

### Shell Script Conventions

- Always start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Container names use the `devportal-` prefix (e.g., `devportal-postgres`).
- Use environment variables with defaults: `CONTAINER="${POSTGRES_CONTAINER:-devportal-postgres}"`.
- Health checks use polling with `MAX_RETRIES` / `RETRY_INTERVAL`.
- SQL runs via `docker exec` — no host-installed `psql` required.
- DDL must be idempotent (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`).

---

## License

This project is proprietary. See the repository owner for licensing details.

---

_Originally written and maintained by contributors and [Devin](https://devin.ai), with updates from the core team._
