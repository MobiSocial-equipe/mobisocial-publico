| ARQUITETURA DE SOFTWARE — TRABALHO FINAL (TEMA 13\) MobiSocial: Transporte e Mobilidade Urbana Inclusiva Criação de Rotas, Agendamento de Corridas, Compartilhamento de Veículos e Gestão de Pagamentos documentado com C4 Model (Structurizr) em Arquitetura SOA \+ Event-Driven (100% Spring Boot) |
| :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |

| Domínio Sorteado (Tema 13\)   | Aplicativo de Transporte e Mobilidade Urbana                                                         |
| :---------------------------- | :--------------------------------------------------------------------------------------------------- |
| **Recorte Social do Produto** | Mobilidade urbana com rotas compartilhadas, acesso estudantil e viagens prioritárias a UBS/Hospitais |
| **Estilos Arquiteturais**     | Orientada a Serviços (SOA) \+ Baseada em Eventos (Event-Driven Architecture)                         |
| **Integrantes (Equipe 10\)**  | Felipe Maia, Clidenor, Pablo, Maria José, Cauan Ricardo e João Vitor                                 |

**01 Definição do Produto: MobiSocial**

O MobiSocial é uma plataforma de transporte e mobilidade urbana que permite criar rotas inteligentes, agendar corridas individuais ou compartilhadas (carpooling), gerenciar passageiros e motoristas e processar pagamentos (incluindo divisão de tarifas e subsídios sociais para estudantes e pacientes em deslocamento para Unidades Básicas de Saúde).

**1.1. Problemas Reais Solucionados**

- **Otimização e Compartilhamento de Veículos:** Reduz o custo individual de deslocamento e o trânsito urbano ao agrupar passageiros com trajetos compatíveis na mesma rota agendada.
- **Acesso à Educação e Saúde (Tarifa Social e Rotas Prioritárias):** Conecta estudantes universitários e pacientes de UBS/hospitais a rotas acessíveis, permitindo pagamentos via rateio solidário, PIX/cartão ou voucher social.
- **Processamento Assíncrono de Corridas e Pagamentos:** Garante que picos de agendamento em horários de rush não travem a alocação de motoristas nem a confirmação financeira das viagens.

**1.2. Atores e Sistemas Externos (Base para C4 Nível 1\)**

- **Passageiro (Usuário Comum / Estudante / Paciente UBS):** Solicita ou agenda corridas via API REST, opta por compartilhamento de veículo e acompanha o status da viagem.
- **Motorista Parceiro / Frota Credenciada:** Cadastra veículos, aceita rotas planejadas e realiza o transporte dos passageiros.
- **Gateway Externo de Pagamentos:** Sistema externo integrado para processar cobranças de corridas, rateios e validação de vouchers sociais.
- **Serviço Externo de Mapas / Geolocalização:** Sistema externo que fornece cálculo de distância, estimativa de tempo e traçado de rotas urbanas.

**1.3. Stack Tecnológica**

- **Serviços de Negócio em Spring Boot (Java 17/21):** Implementa os serviços orientados a capacidades de negócio (Serviço de Rotas e Corridas, Serviço de Pagamentos, Serviço de Usuários e Serviço de Notificações) expondo endpoints REST e comunicando-se via eventos.
- **Mensageria e Eventos (RabbitMQ via Docker):** Intermedia de forma assíncrona os eventos de corrida agendada ('payments.process') e disparo de avisos ('notifications.dispatch').
- **Persistência Relacional (PostgreSQL via Docker):** Armazena usuários, veículos, rotas planejadas, agendamentos de corridas e transações de pagamento via Spring Data JPA.
- **Testes de Requisição (Postman / Insomnia / cURL):** Aciona diretamente os endpoints REST do Spring Boot (ex.: POST /api/rides), eliminando a necessidade de front-end ou scripts externos em Python.

**02 Estilos Arquiteturais Selecionados (Tema 13\)**

- **1\. Arquitetura Orientada a Serviços (SOA — Estilo Recomendado Tema 13):** O sistema é estruturado em serviços modulares orientados a capacidades de negócio bem definidas: Serviço de Rotas e Corridas (Ride Service), Serviço de Pagamentos e Rateio (Payment Service) e Serviço de Notificações (Notification Service), garantindo baixo acoplamento e reutilização.
- **2\. Arquitetura Baseada em Eventos (Event-Driven Architecture — Estilo Recomendado Tema 13):** A integração entre os serviços de negócio ocorre de forma assíncrona via RabbitMQ (AMQP). Ao agendar uma corrida compartilhada via REST, o Serviço de Corridas publica eventos que acionam automaticamente o faturamento com rateio e o envio de notificações sem bloquear a requisição HTTP.

**2.1. Funcionalidades Documentadas (Escopo Tema 13\)**

- **RF01 — Gerenciamento de Usuários e Veículos:** Cadastrar passageiros (com perfil tarifário comum, estudante ou social) e motoristas/veículos com capacidade de assentos.
- **RF02 — Criação e Otimização de Rotas:** Criar rotas urbanas definindo origem, paradas intermediárias, destino e horário previsto.
- **RF03 — Agendamento de Corridas e Compartilhamento:** Receber solicitações de corrida via REST (POST /api/rides) e alocar passageiros na mesma rota/veículo respeitando os assentos disponíveis.
- **RF04 — Gestão de Pagamentos e Rateio:** Consumir o evento de corrida agendada, calcular o valor com desconto de compartilhamento ou tarifa social e processar a cobrança.
- **RF05 — Notificações de Status da Viagem:** Consumir eventos de confirmação e emitir avisos de corrida agendada, motorista alocado e pagamento aprovado.

| Fluxo Principal para a Implementação Parcial (Meta de Código Rodando em 01/12) 1\. O Passageiro envia uma requisição HTTP (POST /api/rides via Postman/cURL) para o RideController (Serviço de Rotas e Corridas). 2\. O RideService aloca o passageiro em uma rota compartilhada ativa, salva no PostgreSQL via RideRepository e publica um evento na fila 'payments.process' do RabbitMQ. 3\. O PaymentEventListener (Serviço de Pagamentos) consome o evento, calcula o rateio/tarifa social no PaymentService, salva o pagamento e publica um evento na fila 'notifications.dispatch'. 4\. O NotificationEventListener (Serviço de Notificações) consome o evento final e registra o envio da confirmação da viagem e do pagamento aprovado. |
| :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |

**03 Estrutura da Documentação Arquitetural (Modelo C4 \+ ADRs)**

| Visão / Artefato              | Prazo     | Elementos Obrigatórios na Modelagem                                                                                                                                                                                                        |
| :---------------------------- | :-------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **C4 Nível 1:Contexto**       | **16/11** | Sistema central 'MobiSocial', atores (Passageiro, Motorista) e sistemas externos (Gateway de Pagamento, API de Mapas).                                                                                                                     |
| **C4 Nível 2:Container**      | **16/11** | Serviço de Rotas e Corridas (Spring Boot REST), Message Broker (RabbitMQ), Serviço de Pagamentos (Spring Boot Worker), Serviço de Notificações e Banco de Dados PostgreSQL (protocolos HTTPS, AMQP, JDBC).                                 |
| **C4 Nível 3:Componentes**    | **23/11** | Componentes internos dos serviços SOA: RideController, RideService, RouteMatchingComponent, RideRepository, PaymentEventListener, PaymentService e NotificationEventListener.                                                              |
| **C4 Nível 4 (Código)e ADRs** | **23/11** | Diagrama de classes do fluxo de agendamento e rateio \+ 3 ADRs (ADR 01: Adoção de SOA para separação de serviços; ADR 02: Event-Driven com RabbitMQ para pagamentos e notificações; ADR 03: Persistência relacional com PostgreSQL e JPA). |

**04 Cronograma Geral e Divisão de Tarefas (Equipe 10\)**

| Etapa       | Prazo | Dupla Responsável                      | Entregável Principal                | Foco Técnico da Frente                                                                                            |
| :---------- | :---- | :------------------------------------- | :---------------------------------- | :---------------------------------------------------------------------------------------------------------------- |
| **Etapa 1** | 16/11 | **Dupla A:Felipe Maia e Clidenor**     | **Repositório GitHub e Estilos**    | Criar repo, estruturar pastas, justificar SOA \+ Event-Driven no README, guia de execução e setup Spring Boot.    |
| **Etapa 1** | 16/11 | **Dupla B:Pablo e Maria**              | **Escopo MobiSocial e Requisitos**  | Documentar o escopo de Mobilidade Urbana, atores, funcionalidades (RF01-RF05) e fluxo principal.                  |
| **Etapa 1** | 16/11 | **Dupla C:Cauan Ricardo e João Vitor** | **Diagramas C4 Níveis 1 e 2**       | Configurar Structurizr DSL (workspace.dsl) e gerar os diagramas de Contexto e Container.                          |
| **Etapa 2** | 23/11 | **Dupla A:Felipe Maia e Clidenor**     | **C4 Nível 3 (Pagamentos/Eventos)** | Modelar os componentes internos do Serviço de Pagamentos, filas do RabbitMQ e Notificações.                       |
| **Etapa 2** | 23/11 | **Dupla B:Pablo e Maria**              | **C4 Nível 3 (Rotas e Corridas)**   | Modelar os componentes internos do Serviço de Rotas e Corridas (RideController, RideService, RideRepository).     |
| **Etapa 2** | 23/11 | **Dupla C:Cauan Ricardo e João Vitor** | **C4 Nível 4 (Código) e ADRs**      | Modelar o diagrama de classes de agendamento/rateio e redigir as ADRs 01, 02 e 03 em /docs/adr.                   |
| **Etapa 3** | 01/12 | **Dupla A:Felipe Maia e Clidenor**     | **Infra Docker e Pagamentos**       | Subir Docker Compose (RabbitMQ \+ PostgreSQL), configurar filas AMQP e implementar o PaymentService.              |
| **Etapa 3** | 01/12 | **Dupla B:Pablo e Maria**              | **Serviço de Rotas e Corridas**     | Implementar endpoint REST (POST /api/rides), pareamento de rota compartilhada e publicação no RabbitMQ.           |
| **Etapa 3** | 01/12 | **Dupla C:Cauan Ricardo e João Vitor** | **Notificações e Conformidade C4**  | Implementar NotificationEventListener, testar fluxo via Postman/cURL e auditar conformidade código x Structurizr. |
