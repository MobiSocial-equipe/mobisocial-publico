# Arquitetura e Estilos Selecionados — MobiSocial

[← Voltar ao README principal](../README.md) · [Produto e Escopo](./produto.md) · [Diagramas C4 →](./c4/README.md) · [ADRs →](./adr/README.md)

---

Para atender aos requisitos do **Tema 13 (Aplicativo de Transporte e Mobilidade Urbana)**, o projeto combina dois estilos arquiteturais complementares: **SOA** e **Event-Driven Architecture**.

## 1. Arquitetura Orientada a Serviços (SOA — Service-Oriented Architecture)

- **Aplicação no Sistema:** Além da **Aplicação Front-end** (`Web App (SPA)`) modelada no C4 Nível 2 — que consome as APIs REST `/api/users`, `/api/auth`, `/api/rides` e `/api/routes` —, o back-end em **Spring Boot** é decomposto em **quatro serviços modulares** orientados a capacidades de negócio independentes, apoiados pelos pacotes transversais `config` (`RabbitMQConfig`, `SecurityConfig`) e `event` (contratos JSON AMQP) e pelo banco **PostgreSQL** (com um schema dedicado por serviço, gerenciado via Flyway):
  * **Serviço de Usuários (`userService` — pacote `user`):** Responsável pelo cadastro de usuários e motoristas/veículos, login com emissão de JWT e gerenciamento dos perfis tarifários (`COMUM`, `ESTUDANTE`, `SOCIAL`) via API REST (`AuthController`, `UserController`, `AuthService`, `UserService`, `UserRepository`).
  * **Serviço de Rotas e Corridas (`rideService` — pacote `ride`):** Responsável pelo cadastro de trajetos (`/api/routes`), controle de capacidade dos veículos, agendamento de corridas compartilhadas (`/api/rides`), validação de JWT, consulta de perfil tarifário e geolocalização, e publicação de eventos (`RouteController`, `RideController`, `RideService`, `RouteMatchingComponent`, `UserServiceClient`, `MapsClient`, `RideEventPublisher`, `RouteRepository`, `RideRepository`).
  * **Serviço de Pagamentos (`paymentService` — pacote `payment`):** Responsável pelo consumo da fila `payments.process`, cálculo de divisão tarifária (*carpooling*), aplicação de subsídio social, cobrança no gateway externo e publicação na fila `notifications.dispatch` (`PaymentEventListener`, `PaymentService`, `PaymentGatewayClient`, `PaymentRepository`, `PaymentEventPublisher`).
  * **Serviço de Notificações (`notificationService` — pacote `notification`):** Responsável pelo consumo da fila `notifications.dispatch`, emissão de avisos de corrida e pagamento e registro dos envios no PostgreSQL (`NotificationEventListener`, `NotificationService`, `NotificationRepository`).
- **Justificativa Arquitetural:** A abordagem **SOA** permite separar claramente as regras de identidade e perfis tarifários (usuários), mobilidade urbana (rotas e lotação), regras financeiras (pagamentos e vouchers) e avisos (notificações), garantindo baixo acoplamento, alta coesão e facilidade de manutenção por duplas em paralelo.

## 2. Arquitetura Baseada em Eventos (Event-Driven Architecture)

- **Aplicação no Sistema:** A comunicação entre os serviços SOA após a solicitação da corrida ocorre de forma totalmente assíncrona por meio do **RabbitMQ** (protocolo `AMQP`), utilizando as filas duráveis `payments.process` e `notifications.dispatch` (com *dead-letter queues* `payments.process.dlq` e `notifications.dispatch.dlq` configuradas em `RabbitMQConfig`).
- **Justificativa Arquitetural:** Em horários de pico no trânsito urbano, centenas de solicitações de agendamento e rateio ocorrem simultaneamente. O estilo orientado a eventos garante **desacoplamento temporal**: o Serviço de Rotas e Corridas confirma a reserva do assento rapidamente via HTTP e delega o processamento financeiro e o envio de avisos para processamento assíncrono em background, aumentando a resiliência e a escalabilidade do sistema.

## 3. Mapa Canônico dos Serviços SOA

| Serviço SOA | Pacote (`...mobisocial`) | Schema PostgreSQL | Filas AMQP (Entrada / Saída) | Componentes Canônicos (C4 Nível 3) |
| :--- | :--- | :--- | :--- | :--- |
| **Serviço de Usuários** (`userService`) | `.user` | `users` | — (HTTP/REST) | `AuthController`, `UserController`, `AuthService`, `UserService`, `UserRepository` |
| **Serviço de Rotas e Corridas** (`rideService`) | `.ride` | `rides` | Publica em `payments.process` | `RouteController`, `RideController`, `RideService`, `RouteMatchingComponent`, `UserServiceClient`, `MapsClient`, `RideEventPublisher`, `RouteRepository`, `RideRepository` |
| **Serviço de Pagamentos** (`paymentService`) | `.payment` | `payments` | Consome `payments.process` → Publica em `notifications.dispatch` | `PaymentEventListener`, `PaymentService`, `PaymentGatewayClient`, `PaymentRepository`, `PaymentEventPublisher` |
| **Serviço de Notificações** (`notificationService`) | `.notification` | `notifications` | Consome `notifications.dispatch` | `NotificationEventListener`, `NotificationService`, `NotificationRepository` |

## 4. Documentos Relacionados

- **Modelagem Visual (C4 Níveis 1 a 4):** [`docs/c4/README.md`](./c4/README.md) e fonte Structurizr em [`docs/c4/workspace.dsl`](./c4/workspace.dsl)
- **Decisões Arquiteturais (ADRs):** [`docs/adr/README.md`](./adr/README.md) ([ADR 01 — SOA](./adr/ADR-01-adocao-de-soa.md), [ADR 02 — RabbitMQ](./adr/ADR-02-event-driven-com-rabbitmq.md), [ADR 03 — PostgreSQL/JPA/Flyway](./adr/ADR-03-persistencia-postgresql-jpa.md))
- **Versionamento SQL (Flyway):** [`src/main/resources/db/migration/README.md`](../src/main/resources/db/migration/README.md)
- **Padrão de Contribuição e Conformidade C4:** [`docs/CONTRIBUTING.md`](./CONTRIBUTING.md)
