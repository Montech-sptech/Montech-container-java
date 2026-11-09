#!/bin/bash

set -e

echo "================================"
echo " Iniciando MonTech Java"
echo "================================"

ENV_FILE="/home/ubuntu/montech-java.env"
CONTAINER_NAME="montech-java"
IMAGE_NAME="montech-java:1.0"
NETWORK_NAME="montech-network"

# Verifica se o arquivo de configuração existe
if [ ! -f "$ENV_FILE" ]; then
    echo "ERRO: Arquivo de configuração não encontrado!"
    exit 1
fi

# Verifica se a imagem Docker existe
if ! sudo docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "ERRO: Imagem Docker não encontrada. Execute build.sh primeiro."
    exit 1
fi

# Remove o container anterior, caso exista
sudo docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Inicia o container
sudo docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    --env-file "$ENV_FILE" \
    -v "$ENV_FILE:/app/.env:ro" \
    -e AWS_EC2_METADATA_DISABLED=false \
    "$IMAGE_NAME"

echo "MonTech Java iniciado com sucesso!"