#!/usr/bin/env bash
# Script de inicialização do LocalStack
# Executado automaticamente quando o LocalStack fica ready

set -euo pipefail

echo "==> Criando bucket S3: devportal-attachments"
awslocal s3 mb s3://devportal-attachments

echo "==> Criando fila SQS: devportal-requests"
awslocal sqs create-queue --queue-name devportal-requests

echo "==> Recursos AWS locais criados com sucesso!"
awslocal s3 ls
awslocal sqs list-queues
