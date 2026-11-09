#!/bin/bash

set -e

CONTAINER_NAME="montech-java"

echo "Parando MonTech Java..."

if sudo docker container inspect "$CONTAINER_NAME" > /dev/null 2>&1; then
    sudo docker stop "$CONTAINER_NAME"
    echo "Container parado com sucesso!"
else
    echo "Container não encontrado."
fi