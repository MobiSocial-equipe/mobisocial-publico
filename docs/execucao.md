# Guia Passo a Passo de Execução do Projeto

[← Voltar ao README principal](../README.md) · [Produto e Fluxo](./produto.md) · [Migrations Flyway](../src/main/resources/db/migration/README.md)

---

> *Nota: Os comandos abaixo descrevem o procedimento completo de execução da infraestrutura, versionamento de banco e fluxo principal em Spring Boot.*

## Pré-requisitos

- **Docker** e **Docker Compose**
- **Java JDK 17+** e **Maven** (ou `./mvnw` / `.\mvnw.cmd`)
- **Postman**, **Insomnia** ou **cURL** (para disparar requisições HTTP aos endpoints REST)

## 1. Configurar Variáveis e Subir a Infraestrutura (RabbitMQ e PostgreSQL)

Na raiz do repositório, copie o arquivo de modelo [`.env.example`](../.env.example) para `.env`, preencha os valores do seu ambiente local (o `.env.example` contém apenas *placeholders* e o `.env` permanece ignorado pelo `.gitignore`) e inicie os containers via [`docker-compose.yml`](../docker-compose.yml):

```bash
cp .env.example .env
# Edite o arquivo .env com suas credenciais locais antes de subir os containers
docker compose up -d
```

- **RabbitMQ (AMQP):** `localhost:5672` | **Painel Web:** `http://localhost:15672`
- **PostgreSQL:** `localhost:5433` *(mapeada na 5433 do host para evitar conflito com instalações locais na 5432)*

## 2. Migrations de Banco de Dados (Flyway)

Ao iniciar a aplicação, o **Flyway** aplica automaticamente as migrations versionadas de `src/main/resources/db/migration/` (iniciando pela criação dos schemas `users`, `rides`, `payments` e `notifications`).

Para gerar novas migrations SQL por módulo durante o desenvolvimento, use o script [`scripts/create-migration.sh`](../scripts/create-migration.sh) conforme documentado em [`src/main/resources/db/migration/README.md`](../src/main/resources/db/migration/README.md):

```bash
./scripts/create-migration.sh payments criar tabela payments
```

## 3. Executar a Aplicação Spring Boot e Testes

Na raiz do repositório, execute os testes ou inicie os serviços do MobiSocial utilizando o Maven Wrapper:

```bash
./mvnw test
./mvnw spring-boot:run
```

## 4. Testar o Fluxo Principal (Usuários/JWT + Agendamento + Evento de Pagamento + Notificação)

Com a aplicação rodando na porta `8080`, execute as requisições abaixo pelo Postman, Insomnia ou via terminal (`curl`) para cadastrar um passageiro no **Serviço de Usuários**, autenticar-se para obter o token **JWT** e agendar uma corrida compartilhada no **Serviço de Rotas e Corridas** (que valida o JWT, consulta o perfil tarifário do passageiro no **Serviço de Usuários** e publica o evento na fila `payments.process`):

1. **Cadastrar passageiro com perfil tarifário (`POST /api/users`):**
```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Ana Silva",
    "email": "ana@alu.ufc.br",
    "password": "senha-segura",
    "tariffProfile": "ESTUDANTE"
  }'
```

2. **Autenticar usuário para obter o token JWT (`POST /api/auth/login`):**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "ana@alu.ufc.br",
    "password": "senha-segura"
  }'
```

3. **Agendar corrida compartilhada com JWT (`POST /api/rides`):**
```bash
curl -X POST http://localhost:8080/api/rides \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN_JWT>" \
  -d '{
    "passengerId": 1,
    "routeId": 10,
    "sharedRide": true,
    "paymentMethod": "PIX"
  }'
```
