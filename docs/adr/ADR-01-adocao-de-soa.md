# ADR 01: Adoção de Arquitetura Orientada a Serviços (SOA) para separação dos serviços

- **Status:** Aceito
- **Data:** 23/11/2026
- **Autores:** Cauan Ricardo
- **Requisitos relacionados:** RF01, RF02, RF03, RF04, RF05
- **Diagramas relacionados:** C4 Nível 2 (`N2-Containers`) e C4 Nível 3 (`N3-Usuarios`, `N3-RotasCorridas`, `N3-Pagamentos`, `N3-Notificacoes`) em [`docs/c4/workspace.dsl`](../c4/workspace.dsl)

## Contexto

O MobiSocial reúne capacidades de negócio bem diferentes entre si:

- **Identidade e perfis tarifários:** cadastro de passageiros e motoristas, login com JWT e perfis `COMUM`, `ESTUDANTE` e `SOCIAL` (RF01).
- **Mobilidade:** criação de rotas, controle de assentos, pareamento de passageiros e agendamento de corridas compartilhadas (RF02 e RF03).
- **Financeiro:** rateio entre passageiros (_carpooling_), desconto de tarifa social e cobrança no gateway externo (RF04).
- **Comunicação:** avisos de corrida e pagamento para passageiro e motorista (RF05).

Cada uma dessas áreas muda por motivos diferentes. Uma regra de subsídio para pacientes de UBS, por exemplo, não deveria exigir alteração no pareamento de rotas. Além disso, a equipe tem seis integrantes divididos em três duplas que trabalham em paralelo, então o sistema precisa ser dividido de forma que cada dupla consiga evoluir sua parte sem pisar no código das outras.

O tema recomenda SOA como um dos estilos arquiteturais, e o prazo da implementação parcial (01/12) é curto, o que limita a complexidade de infraestrutura que a equipe consegue montar.

## Decisão

Adotar uma **Arquitetura Orientada a Serviços (SOA)**, dividindo o back-end em **quatro serviços orientados a capacidades de negócio**, cada um com responsabilidade única e fronteira explícita:

| Serviço (C4 Nível 2)        | Pacote Java    | Responsabilidade                                                 | Componentes (C4 Nível 3)                                                                                                                                                   |
| :-------------------------- | :------------- | :--------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Serviço de Usuários         | `user`         | Cadastro, login (JWT), perfis tarifários e veículos              | `AuthController`, `UserController`, `AuthService`, `UserService`, `UserRepository`                                                                                         |
| Serviço de Rotas e Corridas | `ride`         | Rotas, assentos, pareamento, agendamento e publicação de eventos | `RouteController`, `RideController`, `RideService`, `RouteMatchingComponent`, `UserServiceClient`, `MapsClient`, `RideEventPublisher`, `RouteRepository`, `RideRepository` |
| Serviço de Pagamentos       | `payment`      | Rateio, tarifa social, cobrança e publicação do resultado        | `PaymentEventListener`, `PaymentService`, `PaymentGatewayClient`, `PaymentRepository`, `PaymentEventPublisher`                                                             |
| Serviço de Notificações     | `notification` | Emissão e registro de avisos                                     | `NotificationEventListener`, `NotificationService`, `NotificationRepository`                                                                                               |

Os pacotes transversais `config` (`RabbitMQConfig`, `SecurityConfig`) e `event` (contratos JSON dos eventos AMQP) são compartilhados por todos os serviços.

Regras que acompanham a decisão:

1. **Cada serviço só acessa os próprios dados.** Nenhum serviço usa o `Repository` de outro serviço.
2. **A comunicação entre serviços acontece por contratos explícitos:**
   - **Síncrona (HTTP/REST)** apenas quando a resposta é necessária para continuar a requisição do usuário: o `UserServiceClient` do Serviço de Rotas e Corridas consulta o perfil tarifário no `UserController` do Serviço de Usuários.
   - **Assíncrona (AMQP)** para tudo que acontece depois da confirmação da corrida (pagamento e notificação), conforme o [ADR 02](./ADR-02-event-driven-com-rabbitmq.md).
3. **Integrações externas ficam isoladas em _clients_ dedicados:** `MapsClient` (API de Mapas / Geolocalização) e `PaymentGatewayClient` (Gateway Externo de Pagamentos). Assim, trocar de fornecedor afeta só uma classe.
4. **Estrutura interna padronizada em camadas:** `controller` → `service` → `repository`, com `dto`, `model`, `client` e `messaging` quando necessário. É a estrutura já criada em `src/main/java/br/ufc/quixada/arquitetura/mobisocial`.
5. **Implantação na implementação parcial:** para caber no prazo da disciplina, os quatro serviços são empacotados em uma única aplicação Spring Boot (`mobisocial-core`), separados por pacote. As fronteiras definidas acima continuam valendo, de modo que cada pacote pode ser extraído para uma aplicação própria no futuro sem mudar os contratos.

## Alternativas consideradas

### 1. Monólito em camadas (sem separação por capacidade de negócio)

Uma única aplicação com pacotes `controller`, `service` e `repository` globais.

- **Vantagens:** mais simples de começar e de executar.
- **Por que foi rejeitada:** mistura regras de usuários, rotas, pagamentos e notificações nas mesmas classes, aumenta o acoplamento e gera conflitos de merge entre as duplas. Também não atende ao estilo recomendado pelo tema.

### 2. Microsserviços completos desde o início

Cada serviço como aplicação independente, com deploy, banco e pipeline próprios, além de API Gateway e _service discovery_.

- **Vantagens:** isolamento total de falhas e escalabilidade independente por serviço.
- **Por que foi rejeitada:** o custo operacional (vários containers de aplicação, configuração de rede, descoberta de serviços, observabilidade distribuída) não cabe no prazo da implementação parcial e não é necessário para demonstrar o fluxo principal. A SOA com fronteiras bem definidas mantém essa evolução possível mais adiante.

## Consequências

### Positivas

- **Baixo acoplamento e alta coesão:** cada serviço concentra uma capacidade de negócio, e mudanças em uma regra (por exemplo, cálculo de subsídio) ficam restritas ao serviço responsável.
- **Trabalho em paralelo:** cada dupla é dona de um ou dois pacotes, o que reduz conflitos no GitHub e facilita a revisão dos Pull Requests.
- **Rastreabilidade com o C4:** os nomes de serviços, pacotes e classes são os mesmos nos diagramas e no código, o que viabiliza a regra de conformidade do [`CONTRIBUTING.md`](../CONTRIBUTING.md).
- **Evolução facilitada:** como os serviços só conversam por HTTP e eventos, extrair um pacote para uma aplicação própria exige pouca refatoração.

### Negativas e riscos

- **Chamada síncrona entre serviços:** o agendamento de corrida depende da disponibilidade do Serviço de Usuários. Se ele cair, o `POST /api/rides` falha. _Mitigação:_ definir _timeout_ no `UserServiceClient` e devolver erro claro ao passageiro.
- **Fronteiras dependem de disciplina:** como todos os serviços estão na mesma aplicação, nada impede tecnicamente que uma classe de `payment` importe uma classe de `ride`. _Mitigação:_ revisão obrigatória nos Pull Requests e auditoria de conformidade código × Structurizr na Etapa 3.
- **Escalabilidade conjunta:** enquanto os serviços estiverem na mesma aplicação, não é possível escalar só o Serviço de Pagamentos em horário de pico.
- **Duplicação de alguns dados:** informações como o perfil tarifário precisam trafegar entre serviços (via REST ou no conteúdo dos eventos) em vez de serem lidas diretamente da tabela de outro serviço.

## Referências

- [`docs/arquitetura.md`](../arquitetura.md), seção 1 (Arquitetura Orientada a Serviços) e [`docs/produto.md`](../produto.md)
- [`docs/c4/workspace.dsl`](../c4/workspace.dsl), views `N2-Containers` e `N3-*`
- [ADR 02: Event-Driven com RabbitMQ](./ADR-02-event-driven-com-rabbitmq.md)
- [ADR 03: Persistência relacional com PostgreSQL e JPA](./ADR-03-persistencia-postgresql-jpa.md)
