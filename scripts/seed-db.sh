#!/usr/bin/env bash
# Script para popular o banco de dados MongoDB com collections, índices e dados de teste
# Executa via docker exec — não requer mongosh instalado no host

set -euo pipefail

CONTAINER="${MONGO_CONTAINER:-devportal-mongodb}"
MONGO_USER="${MONGO_USER:-devportal}"
MONGO_PASS="${MONGO_PASS:-devportal}"
MONGO_DB="${MONGO_DB:-devportal}"

echo "==> Conectando ao MongoDB no container ${CONTAINER}..."

docker exec -i "$CONTAINER" mongosh "mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:27017/${MONGO_DB}?authSource=admin" <<'MONGOSCRIPT'

// Collection: users
try {
  db.createCollection("users", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["email", "name", "passwordHash", "createdAt", "updatedAt"],
        properties: {
          email: { bsonType: "string" },
          name: { bsonType: "string" },
          passwordHash: { bsonType: "string" },
          createdAt: { bsonType: "date" },
          updatedAt: { bsonType: "date" }
        }
      }
    }
  });
} catch (e) {
  if (e.codeName !== 'NamespaceExists') throw e;
}
db.users.createIndex({ email: 1 }, { unique: true });

// Collection: requests
try {
  db.createCollection("requests", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["userId", "title", "status", "createdAt", "updatedAt"],
        properties: {
          userId: { bsonType: "objectId" },
          title: { bsonType: "string" },
          description: { bsonType: "string" },
          status: { bsonType: "string", enum: ["PENDING", "APPROVED", "REJECTED"] },
          createdAt: { bsonType: "date" },
          updatedAt: { bsonType: "date" }
        }
      }
    }
  });
} catch (e) {
  if (e.codeName !== 'NamespaceExists') throw e;
}
db.requests.createIndex({ userId: 1 });

// Collection: request_events
try {
  db.createCollection("request_events", {
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: ["requestId", "eventType", "createdAt"],
        properties: {
          requestId: { bsonType: "objectId" },
          eventType: { bsonType: "string" },
          payload: { bsonType: "object" },
          createdAt: { bsonType: "date" }
        }
      }
    }
  });
} catch (e) {
  if (e.codeName !== 'NamespaceExists') throw e;
}
db.request_events.createIndex({ requestId: 1 });

// Usuário de teste
// Senha: DevPortal123! (bcrypt hash)
db.users.updateOne(
  { email: "dev@devportal.local" },
  {
    $setOnInsert: {
      email: "dev@devportal.local",
      name: "Dev User",
      passwordHash: "$2b$10$rjN9E7P0rombOVtOhFryuOVciZSvb.OI8SLfmFdqlFpyHeRCig3cq",
      createdAt: new Date(),
      updatedAt: new Date()
    }
  },
  { upsert: true }
);

print("Seed concluído com sucesso!");
MONGOSCRIPT

echo "==> Banco de dados populado com sucesso!"
