# Cronograma e Divisão de Atividades da Equipe

[← Voltar ao README principal](../README.md) · [Guia de Contribuição](./CONTRIBUTING.md) · [Escopo Original](./escopo.md)

---

**Integrantes (Equipe 10):** Felipe Maia, João Vitor, Maria José, Cauan Ricardo, Clidenor e Pablo.

| Etapa | Prazo Oficial | Dupla Responsável | Entregável Principal | Foco Técnico da Frente |
| :--- | :--- | :--- | :--- | :--- |
| **Etapa 1** | 16/11 | **Dupla A:** Felipe Maia e Clidenor | Repositório GitHub e Estilos | Criar repo, adicionar equipe, estruturar pastas (`/docs/c4`, `/docs/adr`, `/src`), justificar SOA + Event-Driven no `README.md`, guia de execução e importar dependências do Spring Boot. |
| **Etapa 1** | 16/11 | **Dupla B:** Pablo e Maria | Escopo MobiSocial e Requisitos | Documentar o problema de Mobilidade Urbana, atores, funcionalidades (RF01-RF05) e fluxo principal no `README.md`. |
| **Etapa 1** | 16/11 | **Dupla C:** Cauan Ricardo e João Vitor | Diagramas C4 Níveis 1 e 2 | Configurar Structurizr DSL (`workspace.dsl`) e gerar os diagramas de Contexto e Container alinhados ao `README.md`. |
| **Etapa 2** | 23/11 | **Dupla A:** Felipe Maia e Clidenor | C4 Nível 3 (Pagamentos e Notificações) | Modelar os componentes internos do **Serviço de Pagamentos** (`PaymentEventListener`, `PaymentService`, `PaymentGatewayClient`, `PaymentRepository`, `PaymentEventPublisher`), filas do RabbitMQ (`payments.process` e `notifications.dispatch`) e **Serviço de Notificações** (`NotificationEventListener`, `NotificationService`, `NotificationRepository`). |
| **Etapa 2** | 23/11 | **Dupla B:** Pablo e Maria | C4 Nível 3 (Usuários, Rotas e Corridas) | Modelar os componentes internos do **Serviço de Usuários** (`AuthController`, `UserController`, `AuthService`, `UserService`, `UserRepository`) e do **Serviço de Rotas e Corridas** (`RouteController`, `RideController`, `RideService`, `RouteMatchingComponent`, `UserServiceClient`, `MapsClient`, `RideEventPublisher`, `RouteRepository`, `RideRepository`). |
| **Etapa 2** | 23/11 | **Dupla C:** Cauan Ricardo e João Vitor | C4 Nível 4 (Fluxos) e ADRs | Modelar os fluxos dinâmicos de autenticação, agendamento, pagamento/rateio e notificação e redigir as Decisões Arquiteturais (ADRs 01, 02 e 03) em `/docs/adr`. |
| **Etapa 3** | 01/12 | **Dupla A:** Felipe Maia e Clidenor | Infra Docker e Pagamentos | Subir Docker Compose (RabbitMQ + PostgreSQL), configurar filas AMQP (`RabbitMQConfig`) e implementar o **Serviço de Pagamentos** (`PaymentEventListener`, `PaymentService`, `PaymentGatewayClient`, `PaymentRepository`, `PaymentEventPublisher`). |
| **Etapa 3** | 01/12 | **Dupla B:** Pablo e Maria | Serviços de Usuários, Rotas e Corridas | Implementar o **Serviço de Usuários** (`/api/users`, `/api/auth` com JWT e perfis tarifários) e o **Serviço de Rotas e Corridas** (`/api/routes`, `POST /api/rides`, validação de JWT, consulta ao Serviço de Usuários, alocação em rota compartilhada e publicação de evento em `payments.process`). |
| **Etapa 3** | 01/12 | **Dupla C:** Cauan Ricardo e João Vitor | Notificações, Conformidade e Slides | Implementar o **Serviço de Notificações** (`NotificationEventListener`, `NotificationService`, `NotificationRepository`), auditar conformidade código x Structurizr e preparar apresentação. |
