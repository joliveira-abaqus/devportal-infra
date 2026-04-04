# DevPortal — Infraestrutura Local

Infraestrutura de desenvolvimento local para o **DevPortal**. Este repositório contém a configuração Docker Compose e scripts auxiliares para subir todos os serviços necessários para desenvolvimento.

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) (>= 20.10)
- [Docker Compose](https://docs.docker.com/compose/install/) (plugin v2)

## Como rodar

### Setup automático (recomendado)

```bash
./scripts/setup-dev.sh
```

Este script:
1. Verifica se Docker e Docker Compose estão instalados
2. Sobe todos os serviços
3. Aguarda os serviços ficarem healthy
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

| Serviço     | Porta  | Descrição                          |
|-------------|--------|------------------------------------|
| PostgreSQL  | 5432   | Banco de dados principal           |
| Redis       | 6379   | Cache e filas                      |
| LocalStack  | 4566   | Emulação de serviços AWS (S3, SQS) |

### Credenciais

| Serviço    | Usuário     | Senha       | Database    |
|------------|-------------|-------------|-------------|
| PostgreSQL | `devportal` | `devportal` | `devportal` |

### Recursos AWS (LocalStack)

| Recurso          | Nome/URL                                                  |
|------------------|-----------------------------------------------------------|
| S3 Bucket        | `devportal-attachments`                                   |
| SQS Queue        | `http://localhost:4566/000000000000/devportal-requests`   |

### Usuário de teste

| Campo | Valor                  |
|-------|------------------------|
| Email | `dev@devportal.local`  |
| Senha | `DevPortal123!`        |

## Variáveis de Ambiente

Copie o arquivo de exemplo e ajuste conforme necessário:

```bash
cp .env.example .env
```

## Como resetar o ambiente

```bash
# Parar serviços e remover volumes (apaga todos os dados)
docker compose down -v

# Subir novamente do zero
./scripts/setup-dev.sh
```

## Estrutura do Projeto

```
devportal-infra/
├── docker-compose.yml            # Definição dos serviços
├── docker-compose.override.yml   # Overrides para desenvolvimento local
├── localstack/
│   └── init-aws.sh               # Inicialização de recursos AWS locais
├── scripts/
│   ├── seed-db.sh                # Popular banco de dados
│   └── setup-dev.sh              # Setup completo do ambiente
├── .github/
│   └── workflows/
│       └── ci.yml                # Pipeline de CI
├── .env.example                  # Variáveis de ambiente (template)
├── .gitignore                    # Arquivos ignorados pelo Git
└── README.md                     # Esta documentação
```

## CI/CD

O pipeline de CI (GitHub Actions) valida automaticamente em push/PR para `main`:
- Sintaxe do `docker-compose.yml`
- Lint dos shell scripts com `shellcheck`
- Smoke test: sobe os serviços e verifica que estão funcionando
