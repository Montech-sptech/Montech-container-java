#!/bin/bash

CONTAINER_NAME="montech-java"

if ! sudo docker container inspect "$CONTAINER_NAME" > /dev/null 2>&1; then
    echo "ERRO: Container não encontrado."
    exit 1
fi

echo "Acompanhando logs do MonTech Java..."
echo "Pressione Ctrl + C para sair."

sudo docker logs -f --tail 100 "$CONTAINER_NAME"