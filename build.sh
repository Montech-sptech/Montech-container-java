#!/bin/bash

set -e

echo "================================"
echo " Construindo imagem MonTech Java"
echo "================================"

if [ ! -f "MontechLogs-jar-with-dependencies.jar" ]; then
    echo "ERRO: Arquivo JAR não encontrado!"
    echo "Coloque o JAR na pasta do projeto antes de continuar."
    exit 1
fi

sudo docker build -t montech-java:1.0 .

echo "Imagem construída com sucesso!"