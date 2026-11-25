# ADR 02: Arquitetura Event-Driven com RabbitMQ para pagamentos e notificações

- **Status:** Aceito
- **Data:** 23/11/2026
- **Autores:** Cauan Ricardo
- **Requisitos relacionados:** RF03, RF04, RF05
- **Diagramas relacionados:** C4 Nível 2 (`N2-Containers`), C4 Nível 3 (`N3-Broker`, `N3-Pagamentos`, `N3-Notificacoes`) e C4 Nível 4 (`N4-2-Agendamento`, `N4-3-Pagamento`, `N4-4-Notificacao`) em [`docs/c4/workspace.dsl`](../c4/workspace.dsl)

## Contexto

Depois que o passageiro agenda uma corrida (`POST /api/rides`), o sistema ainda precisa:

1. calcular o valor final com rateio entre os passageiros da rota ou desconto de tarifa social;
2. cobrar no **Gateway Externo de Pagamentos** (PIX, cartão ou voucher social);
3. avisar passageiro e motorista sobre a corrida e o pagamento.

Se tudo isso fosse feito dentro da mesma requisição HTTP, o tempo de resposta do agendamento passaria a depender do gateway externo, que é lento e pode ficar indisponível. Nos horários de pico (entrada e saída de aulas, horários de consulta em UBS), muitas solicitações chegam ao mesmo tempo, e uma falha no gateway derrubaria o agendamento inteiro.

Além disso, o [ADR 01](./ADR-01-adocao-de-soa.md) separou os serviços por capacidade de negócio. O Serviço de Rotas e Corridas não deveria precisar conhecer o Serviço de Pagamentos nem o de Notificações para funcionar.

## Decisão

Adotar uma **Arquitetura Baseada em Eventos (Event-Driven)** para tudo que acontece depois da confirmação da corrida, usando o **RabbitMQ** como _message broker_ via protocolo **AMQP** (`spring-boot-starter-amqp`).

### Filas e eventos

| Fila (durável)           | Evento                  | Publicado por                                      | Consumido por                                         |
| :----------------------- | :---------------------- | :------------------------------------------------- | :---------------------------------------------------- |
| `payments.process`       | `RideScheduledEvent`    | `RideEventPublisher` (Serviço de Rotas e Corridas) | `PaymentEventListener` (Serviço de Pagamentos)        |
| `notifications.dispatch` | `PaymentProcessedEvent` | `PaymentEventPublisher` (Serviço de Pagamentos)    | `NotificationEventListener` (Serviço de Notificações) |

Os nomes das filas ficam em `application.properties` (`mobisocial.rabbitmq.queues.*`) e são declarados no `RabbitMQConfig`.

### Fluxo

1. O `RideService` persiste a corrida com status `AGUARDANDO_PAGAMENTO`, aciona o `RideEventPublisher` e **responde imediatamente** ao passageiro.
2. O `PaymentEventListener` consome `RideScheduledEvent`, o `PaymentService` calcula rateio e tarifa social, cobra via `PaymentGatewayClient`, salva a transação e aciona o `PaymentEventPublisher`.
3. O `NotificationEventListener` consome `PaymentProcessedEvent`, e o `NotificationService` emite os avisos e registra o envio.

### Regras dos eventos

- **Formato:** JSON, com os contratos definidos no pacote `event` e compartilhados entre publicador e consumidor.
- **Conteúdo autossuficiente:** o evento leva os dados de que o consumidor precisa (por exemplo, identificador da corrida, da rota e do passageiro, perfil tarifário, distância e método de pagamento), para que o consumidor não precise ler as tabelas de outro serviço (ver [ADR 03](./ADR-03-persistencia-postgresql-jpa.md)).
- **Identificação:** todo evento carrega um identificador único e a data/hora de criação, o que permite detectar mensagens duplicadas.
- **Mudanças de contrato:** qualquer alteração no formato JSON de um evento deve ser destacada na descrição do Pull Request, conforme o [`CONTRIBUTING.md`](../CONTRIBUTING.md).

## Alternativas consideradas

### 1. Chamadas REST síncronas entre os serviços

O Serviço de Rotas e Corridas chamaria o Serviço de Pagamentos por HTTP, que por sua vez chamaria o Serviço de Notificações.

- **Vantagens:** fluxo mais simples de entender e depurar, sem infraestrutura extra.
- **Por que foi rejeitada:** cria acoplamento temporal (todos os serviços precisam estar no ar ao mesmo tempo), deixa o tempo de resposta do agendamento refém do gateway externo e faz uma falha no pagamento ou na notificação derrubar o agendamento.

### 2. Apache Kafka

- **Vantagens:** altíssima vazão, retenção e reprocessamento de eventos (_event log_).
- **Por que foi rejeitada:** é mais pesado de operar (cluster, partições, gerenciamento de _offsets_) e oferece recursos que o fluxo do MobiSocial não exige. O que o projeto precisa é de filas de trabalho ponto a ponto com confirmação de entrega, cenário em que o RabbitMQ é mais simples e tem integração direta com o Spring (`@RabbitListener`, `RabbitTemplate`).

### 3. Eventos internos do Spring (`ApplicationEventPublisher`)

- **Vantagens:** nenhuma infraestrutura adicional.
- **Por que foi rejeitada:** os eventos ficam só na memória da aplicação. Se ela reiniciar, as mensagens pendentes se perdem, e os serviços ficam presos ao mesmo processo, o que impede extraí-los no futuro (ADR 01).

## Consequências

### Positivas

- **Desacoplamento temporal:** o agendamento responde rápido mesmo que o gateway esteja lento ou o Serviço de Pagamentos esteja fora do ar. As mensagens ficam guardadas na fila até serem processadas.
- **Absorção de picos:** em horários de alta demanda, a fila funciona como _buffer_, e os consumidores processam no próprio ritmo.
- **Extensibilidade:** novos consumidores (por exemplo, relatórios de uso da tarifa social) podem ser adicionados sem mudar quem publica.
- **Resiliência:** filas duráveis e confirmação de mensagens (_acknowledgement_) evitam perda de eventos quando um consumidor falha.

### Negativas e riscos

- **Consistência eventual:** logo após o agendamento a corrida fica com status `AGUARDANDO_PAGAMENTO`, e o passageiro só recebe a confirmação final depois do processamento assíncrono. O front-end precisa mostrar esse estado intermediário.
- **Entrega "pelo menos uma vez":** o RabbitMQ pode entregar a mesma mensagem mais de uma vez. _Mitigação:_ os consumidores devem ser idempotentes, verificando pelo identificador do evento (ou da corrida) se o pagamento já foi processado antes de cobrar de novo.
- **Gravação dupla (banco + fila):** se a corrida for salva e a publicação na fila falhar (ou o contrário), os dois ficam inconsistentes. _Mitigação na implementação parcial:_ publicar só depois do _commit_ da transação. _Evolução:_ adotar o padrão _Transactional Outbox_.
- **Mensagens com erro:** um evento que sempre falha pode ficar sendo reprocessado indefinidamente. _Mitigação:_ limitar as tentativas e configurar uma _dead-letter queue_ no `RabbitMQConfig`.
- **Depuração mais difícil:** o fluxo atravessa várias filas e serviços. _Mitigação:_ registrar em log o identificador da corrida em todas as etapas e usar o painel web do RabbitMQ (`localhost:15672`).
- **Infraestrutura adicional:** o RabbitMQ precisa estar em execução (Docker Compose) para o fluxo funcionar.

## Referências

- [`docs/arquitetura.md`](../arquitetura.md), seção 2 (Arquitetura Baseada em Eventos) e [`docs/produto.md`](../produto.md) (Fluxo Principal)
- [`docs/c4/workspace.dsl`](../c4/workspace.dsl), views `N3-Broker`, `N3-Pagamentos`, `N3-Notificacoes` e `N4-*`
- [ADR 01: Adoção de SOA](./ADR-01-adocao-de-soa.md)
- [ADR 03: Persistência relacional com PostgreSQL e JPA](./ADR-03-persistencia-postgresql-jpa.md)
