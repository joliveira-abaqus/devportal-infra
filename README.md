# DevPortal Infrastructure

Local development infrastructure for **DevPortal** — orchestrates containerized backing services (database, cache, cloud emulation) via Docker Compose so developers can run the full stack locally with a single command.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Services](#services)
- [AWS Resources (LocalStack)](#aws-resources-localstack)
- [Environment Variables](#environment-variables)
- [Project Structure](#project-structure)
- [CI/CD](#cicd)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    devportal-infra (Docker Compose)              │
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────┐  │
│  │  PostgreSQL  │   │    Redis     │   │     LocalStack     │  │
│  │  :5432       │   │    :6379     │   │     :4566          │  │
│  │              │   │              │   │                    │  │
│  │  Main DB     │   │  Cache &     │   │  ┌─────┐ ┌─────┐  │  │
│  │  (persistent │   │  Queues      │   │  │ S3  │ │ SQS │  │  │
│  │   volume)    │   │              │   │  └─────┘ └─────┘  │  │
│  └──────────────┘   └──────────────┘   └────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │   devportal-api    │
                    │   (port 3001)      │
                    └─────────┬─────────┘
                              │
                    ┌─────────┴─────────┐
                    │ devportal-frontend │
                    │   (port 3000)      │
                    └───────────────────┘
```

---

## Prerequisites

| Requirement | Minimum Version | Notes |
|---|---|---|
| [Docker](https://docs.docker.com/get-docker/) | >= 20.10 | Engine with BuildKit support |
| [Docker Compose](https://docs.docker.com/compose/install/) | v2 (plugin) | `docker compose` (not `docker-compose`) |

### Compatibility

| OS | Status |
|---|---|
| Linux (x86_64) | Fully supported |
| macOS (Apple Silicon / Intel) | Supported via Docker Desktop |
| Windows (WSL2) | Supported via Docker Desktop + WSL2 |

---

## Quick Start

### Automated Setup (recommended)

```bash
# Clone the repository
git clone https://github.com/joliveira-abaqus/devportal-infra.git
cd devportal-infra

# Copy environment variables
cp .env.example .env

# Run the full setup
./scripts/setup-dev.sh
```

The setup script will:
1. Verify Docker and Docker Compose are installed
2. Start all services in the background
3. Wait for health checks to pass
4. Seed the database with schema and test data

### Manual Setup

```bash
# Start services
docker compose up -d

# Check service status
docker compose ps

# Seed database (schema + test data)
./scripts/seed-db.sh
```

### Stopping & Resetting

```bash
# Stop services (preserves data)
docker compose down

# Stop services AND destroy all data (full reset)
docker compose down -v

# Rebuild from scratch
./scripts/setup-dev.sh
```

---

## Services

| Service | Image | Port | Description |
|---|---|---|---|
| PostgreSQL | `postgres:16-alpine` | 5432 | Primary relational database |
| Redis | `redis:7-alpine` | 6379 | Cache and message queues |
| LocalStack | `localstack/localstack:4.0` | 4566 | AWS S3 + SQS emulation |

> **Important:** Do NOT use `latest` for LocalStack — there is a known bug in the EKS module that breaks local emulation. Always pin to `4.0`.

### Connection Details

| Service | Host | Credentials |
|---|---|---|
| PostgreSQL | `localhost:5432` | User: `devportal` / Password: `devportal` / DB: `devportal` |
| Redis | `localhost:6379` | No authentication |
| LocalStack | `localhost:4566` | Access Key: `test` / Secret: `test` / Region: `us-east-1` |

**Connection string (PostgreSQL):**
```
postgresql://devportal:devportal@localhost:5432/devportal
```

### Test User

| Field | Value |
|---|---|
| Email | `dev@devportal.local` |
| Password | `DevPortal123!` |

---

## AWS Resources (LocalStack)

LocalStack emulates the following AWS services locally (`SERVICES: s3,sqs`):

| Resource | Name / URL | Purpose |
|---|---|---|
| S3 Bucket | `devportal-attachments` | File and attachment storage |
| SQS Queue | `http://localhost:4566/000000000000/devportal-requests` | Async task processing |

These resources are automatically provisioned by `localstack/init-aws.sh` on container start.

> **Note:** LocalStack requires the environment variable `LOCALSTACK_ACKNOWLEDGE_ACCOUNT_REQUIREMENT=1` to be set (already configured in `docker-compose.yml`).

---

## Environment Variables

Copy the example file and adjust as needed:

```bash
cp .env.example .env
```

Refer to `.env.example` for the full list of configurable variables. The defaults are suitable for local development without modification.

---

## Project Structure

```
devportal-infra/
├── docker-compose.yml              # Primary service definitions
├── docker-compose.override.yml     # Local dev overrides (logging, ports)
├── localstack/
│   └── init-aws.sh                 # Provisions S3 bucket and SQS queue
├── scripts/
│   ├── setup-dev.sh                # Full environment bootstrap with health checks
│   └── seed-db.sh                  # Database schema creation and test data
├── .github/
│   └── workflows/
│       └── ci.yml                  # CI pipeline (lint, validate, smoke test)
├── .env.example                    # Environment variable template
├── .gitignore                      # Git ignore rules
└── README.md                       # This documentation
```

---

## CI/CD

The CI pipeline runs automatically on every push and pull request to `main` via **GitHub Actions**:

| Step | Tool | Description |
|---|---|---|
| Config validation | `docker compose config` | Validates compose file syntax |
| Shell linting | `shellcheck` | Static analysis of all `.sh` scripts |
| Smoke test | `docker compose up` | Starts services and verifies connectivity |

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Port 5432 already in use | Stop local PostgreSQL: `sudo systemctl stop postgresql` |
| Port 6379 already in use | Stop local Redis: `sudo systemctl stop redis` |
| LocalStack fails to start | Ensure `LOCALSTACK_ACKNOWLEDGE_ACCOUNT_REQUIREMENT=1` is set |
| Services unhealthy after `up` | Run `docker compose logs <service>` to inspect errors |
| Permission denied on scripts | Run `chmod +x scripts/*.sh localstack/*.sh` |

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Make your changes — only modify infrastructure and scripts
4. Ensure CI passes locally:
   ```bash
   docker compose config --quiet
   shellcheck scripts/*.sh localstack/*.sh
   ```
5. Commit with a descriptive message
6. Open a Pull Request against `main`

---

## License

This project is proprietary to the DevPortal team. All rights reserved.

---

<sub>Originally written and maintained by contributors and [Devin](https://app.devin.ai), with updates from the core team.</sub>
