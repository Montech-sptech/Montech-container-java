
# Utiliza Java 21 em sua versão de execução
FROM eclipse-temurin:21-jre

# Define a pasta de trabalho dentro do container
WORKDIR /app

# Copia o JAR para dentro da imagem
COPY MontechLogs-jar-with-dependencies.jar app.jar

# Comando executado quando o container iniciar
CMD ["java", "-jar", "app.jar"]
