# MonTech Container Java

Repositório responsável por empacotar, construir e executar a aplicação Java do **MonTech** utilizando Docker em uma instância Amazon EC2.

Este projeto permite executar o monitoramento Java do MonTech em um container, sem precisar instalar e configurar manualmente o Java na máquina EC2. A aplicação é empacotada em uma imagem Docker que contém o ambiente de execução necessário.

O objetivo deste repositório é tornar a implantação reproduzível, organizada e simples de atualizar.

---

## Índice

1. [Visão geral](#1-visão-geral)
2. [Arquitetura e responsabilidade dos repositórios](#2-arquitetura-e-responsabilidade-dos-repositórios)
3. [Como funciona o Docker neste projeto](#3-como-funciona-o-docker-neste-projeto)
4. [Pré-requisitos](#4-pré-requisitos)
5. [Implantação completa, desde o zero](#5-implantação-completa-desde-o-zero)
   - [5.1. Preparar a instância EC2](#51-preparar-a-instância-ec2)
   - [5.2. Instalar o Docker](#52-instalar-o-docker)
   - [5.3. Preparar o MySQL e a rede Docker](#53-preparar-o-mysql-e-a-rede-docker)
   - [5.4. Configurar o acesso à AWS e ao S3](#54-configurar-o-acesso-à-aws-e-ao-s3)
   - [5.5. Configurar as variáveis de ambiente](#55-configurar-as-variáveis-de-ambiente)
   - [5.6. Clonar este repositório na EC2](#56-clonar-este-repositório-na-ec2)
   - [5.7. Gerar o JAR da aplicação Java](#57-gerar-o-jar-da-aplicação-java)
   - [5.8. Enviar o JAR para a EC2](#58-enviar-o-jar-para-a-ec2)
   - [5.9. Construir a imagem Docker](#59-construir-a-imagem-docker)
   - [5.10. Executar o container](#510-executar-o-container)
   - [5.11. Validar a implantação](#511-validar-a-implantação)
6. [Implantação rápida: infraestrutura já configurada](#6-implantação-rápida-infraestrutura-já-configurada)
7. [Scripts disponíveis](#7-scripts-disponíveis)
8. [Como atualizar a aplicação](#8-como-atualizar-a-aplicação)
9. [Comandos úteis do Docker](#9-comandos-úteis-do-docker)
10. [Estrutura do repositório](#10-estrutura-do-repositório)
11. [Segurança e boas práticas](#11-segurança-e-boas-práticas)
12. [Problemas comuns](#12-problemas-comuns)

---

## 1. Visão geral

O MonTech utiliza uma aplicação Java para executar atividades de monitoramento da infraestrutura dos servidores.

Essa aplicação depende de serviços externos, principalmente:

- **MySQL:** armazenamento e consulta das informações utilizadas pelo sistema.
- **Amazon S3:** acesso aos dados disponibilizados no Data Lake.
- **Amazon EC2:** máquina virtual responsável por executar o container.
- **Docker:** tecnologia utilizada para empacotar e executar a aplicação Java.

Este repositório não contém o código-fonte da aplicação Java. Ele contém os arquivos necessários para construir sua imagem Docker e controlar seu container.

A aplicação Java continua sendo desenvolvida e compilada no repositório `MonTech-java`.

### Objetivos deste repositório

- Padronizar a execução da aplicação Java.
- Evitar a necessidade de instalar o Java diretamente na EC2.
- Facilitar a construção e atualização da aplicação.
- Separar a configuração de infraestrutura do código-fonte.
- Simplificar o gerenciamento do container por meio de scripts.
- Permitir que outros integrantes reproduzam a implantação seguindo este manual.

---

## 2. Arquitetura e responsabilidade dos repositórios

O MonTech possui diferentes repositórios, cada um com uma responsabilidade específica.

| Repositório | Responsabilidade |
|---|---|
| `MonTech-sh` | Preparação da infraestrutura, instância EC2, Docker e MySQL. |
| `MonTech-java` | Código-fonte Java, regras de negócio, integração com banco de dados e AWS. |
| `MonTech-container-java` | Dockerfile, construção da imagem, execução e gerenciamento do container Java. |
| `MonTech-python` | Processamento e organização dos dados do Data Lake. |
| `MonTech-website` | Interface web do sistema. |

### Como os componentes se comunicam

O fluxo simplificado da implantação é:

```text
                 DESENVOLVEDOR
                       |
                       v
                MonTech-java
                 Código Java
                       |
                       v
                Maven / IntelliJ
                       |
                       v
                  Arquivo JAR
                       |
                 Envio para EC2
                       |
                       v
             MonTech-container-java
                  Dockerfile
                       |
                       v
                Imagem Docker
                       |
                       v
                Container Java
                  /         \
                 v           v
              MySQL       Amazon S3
```

A aplicação Java executa dentro do container e acessa os serviços externos por meio das configurações de conexão e das permissões disponíveis para a instância EC2.

**Importante:** Docker não substitui o MySQL, o S3 ou a aplicação Java. Ele apenas fornece um ambiente padronizado para executar a aplicação.

---

## 3. Como funciona o Docker neste projeto

Antes de iniciar a implantação, é importante compreender três conceitos:

### Dockerfile

É o arquivo que descreve como a imagem deve ser construída.

Neste projeto, o Dockerfile utiliza uma imagem com o ambiente de execução Java 21 e copia o arquivo JAR para dentro dela.

```dockerfile
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY MontechLogs-jar-with-dependencies.jar app.jar

CMD ["java", "-jar", "app.jar"]
```

Entendendo cada instrução:

| Instrução | Função |
|---|---|
| `FROM eclipse-temurin:21-jre` | Define a imagem-base com Java 21 Runtime. |
| `WORKDIR /app` | Define `/app` como diretório de trabalho. |
| `COPY ... app.jar` | Copia o JAR para dentro da imagem. |
| `CMD [...]` | Define o comando executado quando o container inicia. |

A imagem utiliza o **JRE (Java Runtime Environment)** porque precisa executar a aplicação, não compilá-la.

A compilação é realizada anteriormente, no ambiente de desenvolvimento.

### Imagem Docker

É o resultado da construção do Dockerfile.

Neste projeto, a imagem recebe o nome:

```text
montech-java:1.0
```

Ela contém o Java Runtime e o arquivo JAR da aplicação.

### Container

É uma instância em execução de uma imagem.

Quando iniciamos a imagem `montech-java:1.0`, o Docker cria um container chamado:

```text
montech-java
```

É dentro dele que a aplicação Java é executada.

**Resumo:**

- Dockerfile: receita de construção.
- Imagem: resultado da construção.
- Container: aplicação executando a partir da imagem.

---

## 4. Pré-requisitos

Para reproduzir toda a implantação, serão necessários:

### Ambiente local

- Git.
- IntelliJ IDEA ou outra IDE compatível com Maven.
- JDK 21 para compilar a aplicação.
- Maven.
- Cliente SSH.
- Chave privada `.pem` autorizada para acessar a EC2.

### Ambiente AWS

- Conta AWS com permissões para criar ou utilizar uma instância EC2.
- Instância Ubuntu.
- Security Group configurado para permitir acesso SSH.
- Elastic IP, caso seja necessário manter um endereço público estável.
- IAM Role associada à EC2, com permissões necessárias para acessar o S3.
- Bucket S3 utilizado pela aplicação.

### Ambiente EC2

- Ubuntu atualizado.
- Docker instalado.
- Repositório `MonTech-container-java` clonado.
- Container MySQL preparado pelo processo de infraestrutura.
- Rede Docker compartilhada entre MySQL e aplicação Java.

---

# 5. Implantação completa, desde o zero

Esta seção apresenta o processo completo para preparar o ambiente e colocar a aplicação Java em execução dentro de um container Docker.

Algumas etapas de infraestrutura podem ser realizadas pelo repositório `MonTech-sh`. Caso ele já tenha preparado a EC2 e o MySQL, não é necessário repetir essas configurações.

## 5.1. Preparar a instância EC2

A EC2 será a máquina virtual responsável por hospedar os containers.

No console AWS:

1. Acesse o serviço EC2.
2. Escolha a opção para iniciar uma nova instância.
3. Selecione uma imagem Ubuntu compatível.
4. Escolha o tipo de instância adequado à necessidade do projeto.
5. Configure ou selecione um Key Pair para acesso SSH.
6. Configure o Security Group.
7. Associe uma IAM Role com as permissões necessárias para a aplicação.
8. Inicie a instância.

### Security Group

Para este processo, o acesso SSH deve estar permitido na porta:

| Porta | Protocolo | Finalidade |
|---|---|---|
| 22 | TCP | Acesso SSH à EC2. |

Outras portas devem ser liberadas somente quando forem realmente necessárias.

Não é recomendado deixar o MySQL publicamente acessível pela porta 3306. Neste projeto, a aplicação Java acessa o banco pela rede interna do Docker.

### Elastic IP

Caso seja necessário manter um endereço público fixo, associe um Elastic IP à instância.

O endereço público da EC2 será utilizado nos comandos SSH e SCP.

### Acessar a instância

Na máquina local:

```bash
chmod 400 caminho/da-chave.pem
```

Depois:

```bash
ssh -i caminho/da-chave.pem ubuntu@IP_PUBLICO_DA_EC2
```

Substitua:

- `caminho/da-chave.pem` pelo caminho real da chave privada.
- `IP_PUBLICO_DA_EC2` pelo endereço público da instância.

Se a conexão funcionar, você estará no terminal Ubuntu da EC2.

---

## 5.2. Instalar o Docker

Conectado à EC2, atualize os pacotes:

```bash
sudo apt update
sudo apt upgrade -y
```

Instale o Docker:

```bash
sudo apt install docker.io -y
```

Inicie o serviço:

```bash
sudo systemctl start docker
```

Configure para iniciar automaticamente com a máquina:

```bash
sudo systemctl enable docker
```

Verifique a instalação:

```bash
sudo docker --version
```

Verifique se o serviço está ativo:

```bash
sudo systemctl status docker
```

Se aparecer `active (running)`, o Docker está funcionando.

**Por que utilizar `sudo`?**

O usuário Ubuntu normalmente não possui acesso direto ao daemon Docker por padrão. Por isso, os comandos deste manual utilizam `sudo`.

---

## 5.3. Preparar o MySQL e a rede Docker

A aplicação Java precisa acessar o MySQL.

No ambiente MonTech, o banco é executado em um container separado, normalmente chamado:

```text
montech-mysql
```

O banco de dados utilizado é:

```text
montech
```

Se o MySQL já foi criado pelo `MonTech-sh`, não é necessário criar outro banco ou container.

### Verificar se o MySQL está executando

```bash
sudo docker ps
```

Procure pelo container `montech-mysql`.

Caso ele não esteja em execução, será necessário verificar a implantação de infraestrutura antes de continuar.

### Criar uma rede Docker

Os containers precisam compartilhar uma rede para se comunicarem utilizando seus nomes.

Crie a rede:

```bash
sudo docker network create montech-network
```

Se a rede já existir, não é necessário criá-la novamente.

Para verificar:

```bash
sudo docker network ls
```

### Conectar o MySQL à rede

Execute:

```bash
sudo docker network connect montech-network montech-mysql
```

Se o MySQL já estiver conectado, não repita a operação.

Para verificar os containers conectados:

```bash
sudo docker network inspect montech-network
```

O container MySQL deverá aparecer na lista de containers da rede.

### Testar a comunicação com o MySQL

É possível testar a conexão utilizando um container temporário do cliente MySQL:

```bash
sudo docker run --rm -it \
  --network montech-network \
  mysql:8.4 \
  mysqladmin ping -h montech-mysql -u montech -p
```

Informe a senha do usuário MySQL quando solicitado.

O resultado esperado é:

```text
mysqld is alive
```

Isso indica que o cliente conseguiu alcançar o serviço MySQL pela rede Docker.

### Por que utilizar o nome `montech-mysql`?

Dentro da mesma rede Docker, os containers conseguem localizar uns aos outros pelo nome.

Por isso, a aplicação utiliza:

```env
DB_HOST=montech-mysql
```

Não é necessário utilizar o IP interno do container, que pode mudar quando ele é recriado.

---

## 5.4. Configurar o acesso à AWS e ao S3

A aplicação Java utiliza serviços da AWS, incluindo o Amazon S3.

Para isso, a EC2 precisa possuir uma IAM Role associada.

### Associar uma IAM Role à EC2

No console AWS:

1. Acesse EC2.
2. Selecione a instância.
3. Abra as opções de segurança.
4. Localize a opção para modificar a IAM Role.
5. Associe uma Role que possua as permissões necessárias.

No ambiente AWS Academy utilizado durante a implantação do projeto, foi utilizada a Role `LabRole`.

Em outros ambientes, o nome da Role poderá ser diferente.

### Permissões necessárias

A Role precisa permitir as operações que a aplicação realmente executa no bucket utilizado pelo MonTech.

Entre elas, conforme o código da aplicação:

- Listar objetos nos prefixos necessários.
- Consultar os objetos armazenados.
- Ler os arquivos utilizados pelo monitoramento.

As permissões devem ser concedidas somente aos buckets e prefixos necessários.

### Configurar o Instance Metadata Service (IMDS)

O AWS SDK utilizado pela aplicação pode obter as credenciais temporárias diretamente da IAM Role associada à EC2.

Para isso, a instância precisa disponibilizar o serviço de metadados.

Neste ambiente, foram utilizadas as seguintes configurações:

- Endpoint HTTP do IMDS habilitado.
- IMDSv2 obrigatório.
- Hop limit de resposta igual a `2`, permitindo que o container alcance o serviço de metadados.

O hop limit é importante porque a aplicação executa dentro de um container Docker e precisa conseguir acessar o endpoint de metadados da instância.

### Verificar a identidade da EC2

Na EC2, execute:

```bash
aws sts get-caller-identity
```

Se o AWS CLI estiver configurado com credenciais próprias, ele poderá utilizar essas credenciais em vez da IAM Role.

Para testar especificamente a Role da instância, desconsidere o arquivo local de credenciais:

```bash
AWS_SHARED_CREDENTIALS_FILE=/dev/null aws sts get-caller-identity
```

O resultado deverá indicar uma identidade assumida pela Role associada à EC2.

### Testar o acesso ao S3

Exemplo:

```bash
AWS_SHARED_CREDENTIALS_FILE=/dev/null \
aws s3 ls s3://SEU_BUCKET/03-gold/
```

Substitua `SEU_BUCKET` pelo bucket utilizado pelo projeto.

Se os objetos forem listados, o teste de acesso ao prefixo funcionou.

**Importante:** não utilize credenciais AWS permanentes dentro do Dockerfile, do código-fonte ou do arquivo `.env`. Prefira a IAM Role da EC2, que fornece credenciais temporárias automaticamente.

---

## 5.5. Configurar as variáveis de ambiente

A aplicação precisa conhecer os dados de conexão com o banco e o bucket S3.

Para isso, será utilizado um arquivo externo chamado:

```text
montech-java.env
```

Esse arquivo ficará na EC2, fora do repositório.

Crie o arquivo:

```bash
nano ~/montech-java.env
```

Adicione as variáveis:

```env
DB_HOST=montech-mysql
DB_PORT=3306
DB_NAME=montech
DB_USER=montech
DB_PASSWORD=SUA_SENHA_DO_MYSQL
MONTECH_BUCKET=SEU_BUCKET_S3
```

Substitua os valores de exemplo pelas informações reais do ambiente.

Salve o arquivo.

Restrinja as permissões:

```bash
chmod 600 ~/montech-java.env
```

Isso impede que outros usuários comuns da máquina leiam o arquivo.

### Por que o arquivo fica fora do repositório?

O arquivo pode conter informações sensíveis, como a senha do banco de dados.

Mantê-lo fora do Git evita que credenciais sejam publicadas acidentalmente.

### Como a aplicação recebe essas informações?

O script `run.sh` utiliza duas configurações:

```bash
--env-file /home/ubuntu/montech-java.env
```

Essa opção disponibiliza as variáveis de ambiente para o container.

Também utiliza:

```bash
-v /home/ubuntu/montech-java.env:/app/.env:ro
```

Essa opção monta o arquivo dentro do container como `/app/.env`, em modo somente leitura.

Isso é necessário porque a aplicação também utiliza a biblioteca Dotenv para carregar configurações do arquivo `.env`.

O caminho `/app/.env` corresponde ao diretório de trabalho definido no Dockerfile.

---

## 5.6. Clonar este repositório na EC2

Na EC2, clone o repositório:

```bash
git clone https://github.com/MonTech-sptech/MonTech-container-java.git
```

Entre na pasta:

```bash
cd MonTech-container-java
```

Confira os arquivos:

```bash
ls -la
```

A estrutura deverá conter:

```text
MonTech-container-java/
├── Dockerfile
├── .dockerignore
├── .gitignore
├── build.sh
├── run.sh
├── stop.sh
├── logs.sh
└── README.md
```

O arquivo JAR será enviado posteriormente para essa mesma pasta.

---

## 5.7. Gerar o JAR da aplicação Java

Esta etapa acontece na máquina local, no repositório `MonTech-java`.

O Docker não compila o código Java neste projeto. Primeiro, geramos o arquivo executável e depois o enviamos para a EC2.

### Abrir o projeto

1. Abra o repositório `MonTech-java` no IntelliJ IDEA.
2. Aguarde o Maven carregar as dependências.
3. Abra a aba Maven.
4. Localize `Lifecycle`.
5. Execute `clean`.
6. Execute `package`.

Também é possível utilizar o terminal na pasta do projeto:

```bash
mvn clean package
```

### Resultado esperado

O Maven deverá gerar o arquivo:

```text
target/MontechLogs-jar-with-dependencies.jar
```

Esse é o arquivo que será enviado para a EC2.

### Por que utilizar o JAR com dependências?

A aplicação utiliza bibliotecas externas.

O JAR com dependências reúne a aplicação e suas bibliotecas necessárias para execução, evitando depender de uma instalação manual de cada biblioteca na EC2.

O nome do arquivo precisa corresponder ao nome esperado pelo Dockerfile.

---

## 5.8. Enviar o JAR para a EC2

Ainda na máquina local, execute o comando SCP:

```bash
scp -i caminho/da-chave.pem \
target/MontechLogs-jar-with-dependencies.jar \
ubuntu@IP_PUBLICO_DA_EC2:~/MonTech-container-java/
```

Substitua o caminho da chave e o IP pelo ambiente correspondente.

O comando SCP copia o arquivo pela conexão SSH.

### Verificar o envio

Conecte-se à EC2 ou utilize o terminal já aberto e execute:

```bash
cd ~/MonTech-container-java
ls -lh
```

O arquivo deverá aparecer:

```text
MontechLogs-jar-with-dependencies.jar
```

**Atenção:** o JAR não deve ser enviado para o GitHub. Ele é um artefato de implantação, não parte do código-fonte deste repositório.

---

## 5.9. Construir a imagem Docker

Com o JAR dentro da pasta do repositório na EC2, execute:

```bash
cd ~/MonTech-container-java
```

Dê permissão aos scripts, caso ainda não estejam executáveis:

```bash
chmod +x build.sh run.sh stop.sh logs.sh
```

Agora construa a imagem:

```bash
./build.sh
```

O script verifica se o JAR existe e executa:

```bash
sudo docker build -t montech-java:1.0 .
```

### O que acontece durante a construção?

1. O Docker lê o Dockerfile.
2. Baixa a imagem-base Java 21, caso ainda não esteja disponível.
3. Define `/app` como diretório de trabalho.
4. Copia o JAR para dentro da imagem com o nome `app.jar`.
5. Registra o comando que será executado quando o container iniciar.
6. Cria a imagem `montech-java:1.0`.

### Verificar a imagem

```bash
sudo docker images
```

Procure por:

```text
montech-java
```

Se a imagem aparecer, a construção foi concluída.

---

## 5.10. Executar o container

Antes de executar, verifique se:

- O MySQL está ativo.
- O MySQL está conectado à rede `montech-network`.
- O arquivo `/home/ubuntu/montech-java.env` existe.
- A imagem `montech-java:1.0` foi construída.
- A EC2 possui acesso à IAM Role e ao S3.

Execute:

```bash
./run.sh
```

O script realiza as seguintes operações:

1. Verifica se o arquivo de configuração existe.
2. Verifica se a imagem Docker existe.
3. Remove um container anterior chamado `montech-java`, caso exista.
4. Cria um novo container.
5. Conecta o container à rede `montech-network`.
6. Disponibiliza as variáveis do arquivo `.env`.
7. Monta o arquivo `.env` em modo somente leitura.
8. Habilita o acesso aos metadados da EC2 para obtenção das credenciais AWS.
9. Inicia a aplicação Java em segundo plano.

O container recebe o nome:

```text
montech-java
```

A opção `-d` permite que o container continue executando em segundo plano, mesmo depois de sair da sessão SSH.

### Verificar se está executando

```bash
sudo docker ps
```

O container `montech-java` deverá aparecer com status semelhante a:

```text
Up
```

Se não aparecer, consulte os containers encerrados:

```bash
sudo docker ps -a
```

Depois verifique os logs:

```bash
./logs.sh
```

---

## 5.11. Validar a implantação

A aplicação pode iniciar sem apresentar erros de conexão, mas é importante validar seu funcionamento.

### 1. Verificar o container

```bash
sudo docker ps
```

Confirme que `montech-java` está em execução.

### 2. Verificar os logs

```bash
./logs.sh
```

Observe se a aplicação consegue iniciar e executar seus ciclos de monitoramento.

Uma inicialização bem-sucedida pode apresentar mensagens semelhantes a:

```text
Monitor iniciado.
5 servidor(es) ativo(s) para analisar.
Lendo JSON do dia no S3...
Ciclo finalizado.
```

As mensagens exatas dependem dos dados disponíveis e do estado do ambiente.

### 3. Verificar o MySQL

Confirme que o container MySQL continua ativo:

```bash
sudo docker ps
```

### 4. Verificar o acesso ao S3

Observe os logs da aplicação.

Se a aplicação conseguir consultar os objetos do S3, sem apresentar erros de autorização ou obtenção de credenciais, o acesso está funcionando.

**Importante:** uma mensagem como `Sem JSON hoje, nada para analisar` não significa necessariamente que a integração falhou. Pode simplesmente não haver arquivos disponíveis para a data consultada.

A validação deve diferenciar ausência de dados de erros de conexão ou permissão.

---

# 6. Implantação rápida: infraestrutura já configurada

Esta seção é destinada a quem já possui:

- EC2 criada e acessível por SSH.
- Docker instalado.
- MySQL em execução.
- Rede `montech-network` criada.
- MySQL conectado à rede.
- IAM Role associada à EC2 com acesso ao S3.
- Arquivo `/home/ubuntu/montech-java.env` configurado.

Nesse cenário, não é necessário repetir as etapas de preparação da infraestrutura.

### Passo 1. Gerar o JAR localmente

No repositório `MonTech-java`, execute:

```bash
mvn clean package
```

Ou utilize as tarefas `clean` e `package` pela aba Maven do IntelliJ.

### Passo 2. Enviar o JAR para a EC2

Na máquina local:

```bash
scp -i caminho/da-chave.pem \
target/MontechLogs-jar-with-dependencies.jar \
ubuntu@IP_PUBLICO_DA_EC2:~/MonTech-container-java/
```

### Passo 3. Acessar a EC2

```bash
ssh -i caminho/da-chave.pem ubuntu@IP_PUBLICO_DA_EC2
```

### Passo 4. Entrar no repositório

```bash
cd ~/MonTech-container-java
```

### Passo 5. Construir a imagem

```bash
./build.sh
```

### Passo 6. Executar a aplicação

```bash
./run.sh
```

### Passo 7. Acompanhar os logs

```bash
./logs.sh
```

Pronto! A aplicação Java estará executando dentro do container Docker.

---

# 7. Scripts disponíveis

Este repositório possui quatro scripts para facilitar o gerenciamento da aplicação.

| Script | Função |
|---|---|
| `build.sh` | Constrói a imagem Docker. |
| `run.sh` | Cria e inicia o container. |
| `stop.sh` | Para o container em execução. |
| `logs.sh` | Exibe e acompanha os logs. |

### build.sh

```bash
./build.sh
```

Verifica se o JAR existe e constrói a imagem:

```text
montech-java:1.0
```

É necessário executá-lo quando uma nova versão do JAR for enviada.

### run.sh

```bash
./run.sh
```

Inicia a aplicação.

Se já existir um container com o nome `montech-java`, ele será removido e recriado.

Isso significa que o script utiliza a imagem disponível no momento da execução.

### stop.sh

```bash
./stop.sh
```

Para o container Java.

Esse comando não remove a imagem, não apaga o JAR e não interrompe o MySQL.

### logs.sh

```bash
./logs.sh
```

Exibe os últimos 100 registros e continua acompanhando os novos logs.

Para interromper apenas a visualização, pressione:

```text
Ctrl + C
```

Isso não encerra o container. A aplicação continua executando em segundo plano.

---

# 8. Como atualizar a aplicação

Quando houver alterações no código Java, não é necessário recriar a EC2 ou instalar novamente o Docker.

O processo de atualização consiste em gerar um novo JAR e reconstruir a imagem.

### Etapa 1. Atualizar o código Java

Faça as alterações necessárias no repositório `MonTech-java`.

### Etapa 2. Gerar um novo JAR

Execute:

```bash
mvn clean package
```

### Etapa 3. Enviar o novo JAR

Na máquina local:

```bash
scp -i caminho/da-chave.pem \
target/MontechLogs-jar-with-dependencies.jar \
ubuntu@IP_PUBLICO_DA_EC2:~/MonTech-container-java/
```

O arquivo anterior será substituído pelo novo.

### Etapa 4. Acessar a EC2

```bash
ssh -i caminho/da-chave.pem ubuntu@IP_PUBLICO_DA_EC2
```

### Etapa 5. Construir novamente a imagem

```bash
cd ~/MonTech-container-java
./build.sh
```

A imagem `montech-java:1.0` será reconstruída com o novo JAR.

### Etapa 6. Recriar o container

```bash
./run.sh
```

O script removerá o container anterior e criará outro utilizando a imagem atualizada.

### Etapa 7. Verificar a execução

```bash
./logs.sh
```

Confira se a nova versão iniciou corretamente.

### O que não precisa ser feito novamente?

Em uma atualização comum do código Java, não é necessário:

- Criar outra EC2.
- Instalar novamente o Docker.
- Criar outro MySQL.
- Reconfigurar a rede Docker.
- Criar outro arquivo `.env`.
- Associar novamente a IAM Role, caso ela continue configurada corretamente.

---

# 9. Comandos úteis do Docker

Os comandos abaixo ajudam a consultar e administrar os containers.

### Listar containers em execução

```bash
sudo docker ps
```

### Listar todos os containers, inclusive os parados

```bash
sudo docker ps -a
```

### Listar imagens disponíveis

```bash
sudo docker images
```

### Consultar os logs do container

```bash
sudo docker logs montech-java
```

### Acompanhar os logs continuamente

```bash
sudo docker logs -f --tail 100 montech-java
```

### Parar o container

```bash
sudo docker stop montech-java
```

### Iniciar um container que já existe

```bash
sudo docker start montech-java
```

### Remover um container parado

```bash
sudo docker rm montech-java
```

### Consultar as redes Docker

```bash
sudo docker network ls
```

### Inspecionar uma rede

```bash
sudo docker network inspect montech-network
```

### Consultar informações de um container

```bash
sudo docker inspect montech-java
```

### Consultar o uso de recursos

```bash
sudo docker stats
```

---

# 10. Estrutura do repositório

A estrutura esperada é:

```text
MonTech-container-java/
│
├── Dockerfile
│
├── .dockerignore
├── .gitignore
│
├── build.sh
├── run.sh
├── stop.sh
├── logs.sh
│
└── README.md
```

### Dockerfile

Define o ambiente de execução da aplicação Java e as instruções para construir a imagem.

### .dockerignore

Define os arquivos que não devem ser enviados ao contexto de construção do Docker.

Exemplo:

```text
.env
.env.*
*.pem
.git
.idea
*.log
```

Isso evita incluir arquivos desnecessários ou sensíveis na construção da imagem.

### .gitignore

Define arquivos que não devem ser versionados pelo Git.

Exemplo:

```text
.env
.env.*
*.pem
*.jar
*.log
.idea/
```

O JAR é gerado separadamente e enviado para a EC2.

### build.sh

Responsável por construir a imagem Docker.

### run.sh

Responsável por criar e iniciar o container.

### stop.sh

Responsável por interromper a execução do container.

### logs.sh

Responsável por acompanhar os registros da aplicação.

### README.md

Documentação do projeto e manual de implantação.

---

# 11. Segurança e boas práticas

Algumas práticas são importantes para manter a implantação segura.

### Não versionar credenciais

Nunca envie para o GitHub:

- Senhas do MySQL.
- Arquivos `.env`.
- Chaves privadas `.pem`.
- Credenciais permanentes da AWS.

O `.gitignore` e o `.dockerignore` já ajudam a evitar que esses arquivos sejam incluídos acidentalmente.

### Utilizar IAM Role

A aplicação deve utilizar a IAM Role associada à EC2 para acessar os serviços AWS.

Evite armazenar Access Keys e Secret Keys diretamente no código ou no arquivo de configuração.

### Restringir o acesso ao MySQL

O banco deve ser acessado pela rede interna do Docker sempre que possível.

Não exponha a porta 3306 publicamente sem necessidade.

### Preservar os dados do MySQL

O container Java e o container MySQL possuem responsabilidades diferentes.

O script `stop.sh` interrompe somente a aplicação Java.

A recriação do container Java não deve afetar o banco de dados.

No ambiente preparado pelo `MonTech-sh`, o MySQL utiliza um volume Docker persistente, chamado `montech_mysql_data`, para armazenar os dados.

Não remova volumes do MySQL durante uma atualização comum da aplicação.

### Não confundir imagem e container

A imagem contém a versão empacotada da aplicação.

O container é a instância que está executando essa versão.

Quando o código Java mudar, é necessário reconstruir a imagem e recriar o container.

---

# 12. Problemas comuns

## 12.1. Erro: JAR não encontrado

Mensagem:

```text
ERRO: Arquivo JAR não encontrado!
```

**Causa:** o arquivo JAR não está na pasta do repositório na EC2.

**Solução:**

1. Gere novamente o JAR no `MonTech-java`.
2. Envie-o utilizando SCP.
3. Confira se está no diretório correto:

```bash
ls -lh ~/MonTech-container-java/
```

O nome precisa ser exatamente:

```text
MontechLogs-jar-with-dependencies.jar
```

## 12.2. Erro: imagem Docker não encontrada

Mensagem:

```text
ERRO: Imagem Docker não encontrada.
```

**Causa:** a imagem ainda não foi construída ou foi removida.

**Solução:**

```bash
./build.sh
```

Depois:

```bash
./run.sh
```

## 12.3. Erro: arquivo de configuração não encontrado

Mensagem:

```text
ERRO: Arquivo de configuração não encontrado!
```

**Causa:** o arquivo `/home/ubuntu/montech-java.env` não existe ou está em outro caminho.

**Solução:**

```bash
ls -l /home/ubuntu/montech-java.env
```

Se não existir, crie novamente:

```bash
nano ~/montech-java.env
```

Confira as variáveis e as permissões:

```bash
chmod 600 ~/montech-java.env
```

## 12.4. Erro de conexão com o MySQL

**Possíveis causas:**

- MySQL parado.
- Container Java fora da rede correta.
- Container MySQL fora da rede.
- Nome do host incorreto.
- Credenciais incorretas.

**Verificações:**

```bash
sudo docker ps
```

```bash
sudo docker network inspect montech-network
```

Confira também:

```env
DB_HOST=montech-mysql
DB_PORT=3306
DB_NAME=montech
DB_USER=montech
```

Se necessário, conecte o MySQL à rede:

```bash
sudo docker network connect montech-network montech-mysql
```

Não execute essa operação novamente se o MySQL já estiver conectado.

## 12.5. Erro de credenciais ou acesso ao S3

Mensagens relacionadas a:

```text
Unable to load credentials
```

ou:

```text
AccessDenied
```

podem indicar problemas diferentes.

**Unable to load credentials:** a aplicação não conseguiu obter credenciais AWS.

Verifique:

- Se a EC2 possui uma IAM Role associada.
- Se o endpoint de metadados está habilitado.
- Se o IMDS está acessível pelo container.
- Se a configuração do IMDSv2 permite o acesso a partir do container.
- Se o container foi iniciado com `AWS_EC2_METADATA_DISABLED=false`.

**AccessDenied:** a aplicação conseguiu obter uma identidade AWS, mas ela não possui autorização para realizar a operação solicitada.

Verifique as permissões da IAM Role para o bucket e os prefixos utilizados.

## 12.6. Container inicia e encerra imediatamente

Verifique:

```bash
sudo docker ps -a
```

Depois consulte:

```bash
sudo docker logs montech-java
```

O container pode encerrar quando a aplicação encontra uma exceção durante a inicialização ou termina sua execução.

Analise a mensagem de erro nos logs antes de tentar recriá-lo.

## 12.7. Aviso do Docker sobre o Legacy Builder

Durante a construção da imagem, pode aparecer:

```text
DEPRECATED: The legacy builder is deprecated
```

Esse aviso indica que o Docker está utilizando o construtor antigo.

Ele não significa necessariamente que a construção falhou.

A imagem pode ser construída normalmente, mas é recomendável migrar para o BuildKit/buildx em uma melhoria futura.

## 12.8. Aviso SLF4J

Pode aparecer:

```text
Failed to load class "org.slf4j.impl.StaticLoggerBinder".
Defaulting to no-operation (NOP) logger implementation
```

Esse aviso está relacionado à configuração da biblioteca de logging SLF4J.

Ele não significa, por si só, que a conexão com MySQL ou S3 falhou. Deve ser tratado separadamente caso seja necessário corrigir ou habilitar a saída de logs dessa biblioteca.

---

## Considerações finais

O repositório `MonTech-container-java` foi criado para simplificar a implantação e a execução da aplicação Java do MonTech.

A separação de responsabilidades permite que:

- O código Java continue sendo desenvolvido no `MonTech-java`.
- A infraestrutura seja preparada pelo processo de infraestrutura do MonTech.
- O Docker seja responsável por empacotar e executar a aplicação.
- A configuração sensível permaneça fora do repositório.
- Atualizações sejam realizadas sem reconstruir toda a infraestrutura.

Com essa estrutura, o processo normal de atualização fica reduzido a três operações principais:

```text
1. Gerar o JAR no MonTech-java.
2. Enviar o JAR para a EC2.
3. Construir a imagem e recriar o container.
```

O resultado é uma implantação mais organizada, reproduzível e simples de manter.