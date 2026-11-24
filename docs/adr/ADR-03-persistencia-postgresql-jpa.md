# ADR 03: Persistência relacional com PostgreSQL e Spring Data JPA

- **Status:** Aceito
- **Data:** 23/11/2026
- **Autores:** Cauan Ricardo
- **Requisitos relacionados:** RF01, RF02, RF03, RF04, RF05
- **Diagramas relacionados:** C4 Nível 2 (`N2-Containers`, container "Banco de Dados") e componentes `*Repository` do C4 Nível 3 em [`docs/c4/workspace.dsl`](../c4/workspace.dsl)

## Contexto

O MobiSocial precisa guardar dados fortemente relacionados entre si:

- **Usuários:** passageiros, motoristas, perfis tarifários (`COMUM`, `ESTUDANTE`, `SOCIAL`) e veículos com capacidade de assentos.
- **Mobilidade:** rotas com origem, paradas, destino, horário e assentos disponíveis, além das corridas agendadas e seus status.
- **Financeiro:** transações, rateios entre passageiros e subsídios aplicados.
- **Comunicação:** histórico de notificações enviadas.

Dois pontos exigem garantias fortes de consistência:

1. **Lotação dos veículos:** dois passageiros não podem ocupar o último assento da mesma rota ao mesmo tempo.
2. **Dados financeiros:** um pagamento não pode ser registrado pela metade nem duplicado.

Ao mesmo tempo, o [ADR 01](./ADR-01-adocao-de-soa.md) definiu que cada serviço só acessa os próprios dados. A equipe já conhece SQL e o ecossistema Spring, e o `pom.xml` já inclui `spring-boot-starter-data-jpa` e o driver `postgresql`.

## Decisão

Usar o **PostgreSQL** como banco de dados relacional e o **Spring Data JPA** (Hibernate) como camada de acesso, com as regras abaixo.

### 1. Um schema por serviço

Uma única instância do PostgreSQL (executada via Docker Compose) com **um schema por serviço**, conforme a descrição do container "Banco de Dados" no C4 Nível 2:

| Schema          | Dono                        | Repositórios                        | Dados principais                      |
| :-------------- | :-------------------------- | :---------------------------------- | :------------------------------------ |
| `users`         | Serviço de Usuários         | `UserRepository`                    | usuários, perfis tarifários, veículos |
| `rides`         | Serviço de Rotas e Corridas | `RouteRepository`, `RideRepository` | rotas, paradas, assentos, corridas    |
| `payments`      | Serviço de Pagamentos       | `PaymentRepository`                 | transações, rateios, subsídios        |
| `notifications` | Serviço de Notificações     | `NotificationRepository`            | histórico de envios                   |

- Cada entidade JPA declara o próprio schema (`@Table(schema = "...")`).
- **Não há chave estrangeira nem _join_ entre schemas de serviços diferentes.** Referências a dados de outro serviço são guardadas só como identificador (por exemplo, `passengerId` em `rides`). Os dados de que um serviço precisa chegam pela API REST ou pelo conteúdo dos eventos ([ADR 02](./ADR-02-event-driven-com-rabbitmq.md)).

### 2. Acesso exclusivo pelos `Repository`

Todo acesso ao banco passa pelos componentes `*Repository` (interfaces do Spring Data JPA) do próprio serviço. _Controllers_ e _listeners_ nunca acessam o banco diretamente.

### 3. Consistência

- As operações de negócio rodam em transações (`@Transactional`) na camada `service`.
- O controle de assentos no `RideService` usa **bloqueio otimista** (`@Version` na entidade de rota) para impedir que dois agendamentos simultâneos ultrapassem a capacidade do veículo.
- Senhas são armazenadas apenas como _hash_ (BCrypt, via Spring Security), nunca em texto puro.

### 4. Evolução do esquema

O versionamento de esquema SQL é gerenciado pelo **Flyway** (`spring-boot-starter-flyway` e `flyway-database-postgresql`), com varredura recursiva em `classpath:db/migration`. As migrations usam prefixo de timestamp `yyyyMMddHHmmss` (`VyyyyMMddHHmmss__descricao.sql`), são organizadas por módulo (`users/`, `rides/`, `payments/`, `notifications/`) e criadas com o utilitário [`scripts/create-migration.sh`](../../scripts/create-migration.sh) (instruções em [`src/main/resources/db/migration/README.md`](../../src/main/resources/db/migration/README.md)).

Durante o desenvolvimento incremental das entidades na Etapa 3, `spring.jpa.hibernate.ddl-auto=update` permanece ativo de forma transitória, devendo ser alterado para `validate` assim que as tabelas iniciais dos quatro serviços estiverem versionadas em migrations SQL.

## Alternativas consideradas

### 1. Banco NoSQL de documentos (MongoDB)

- **Vantagens:** esquema flexível e boa escrita em grande volume.
- **Por que foi rejeitada:** os dados do MobiSocial são relacionais por natureza (usuário → corrida → rota → pagamento), e o controle de assentos e de pagamentos depende de transações ACID, que são o ponto forte de um banco relacional.

### 2. Um banco físico separado para cada serviço

- **Vantagens:** isolamento máximo entre serviços.
- **Por que foi rejeitada:** multiplica containers e configurações sem ganho prático na implementação parcial. Schemas separados já garantem a posse dos dados por serviço e permitem mover cada schema para um banco próprio no futuro.

### 3. JDBC puro ou `JdbcTemplate` em vez de JPA

- **Vantagens:** controle total do SQL e menos "mágica" do framework.
- **Por que foi rejeitada:** exige escrever e manter manualmente o mapeamento e o CRUD de todas as entidades. O Spring Data JPA gera os repositórios a partir de interfaces, o que acelera a Etapa 3, e ainda permite SQL nativo quando for necessário.

### 4. Banco em memória (H2)

- **Vantagens:** não precisa de Docker e sobe instantaneamente.
- **Por que foi rejeitada para produção:** não representa o ambiente real e tem diferenças de comportamento em relação ao PostgreSQL. Pode ser usado somente em testes automatizados, se a equipe quiser.

## Consequências

### Positivas

- **Integridade dos dados:** transações ACID, chaves estrangeiras dentro do schema de cada serviço e restrições (`NOT NULL`, `UNIQUE`) protegem os dados de usuários, assentos e pagamentos.
- **Produtividade:** o Spring Data JPA reduz o código repetitivo de acesso a dados, e os nomes dos repositórios batem com o C4 Nível 3.
- **Posse clara dos dados:** cada serviço é dono do próprio schema, o que reforça as fronteiras do ADR 01.
- **Infraestrutura simples:** um único container PostgreSQL no Docker Compose atende os quatro serviços.
- **Ferramentas maduras:** o PostgreSQL é gratuito e bem documentado, com bom suporte a consultas e, se necessário, extensões geográficas (PostGIS) para o pareamento de rotas.
- **Evolução controlada com Flyway:** alterações estruturais do banco ficam rastreadas e reproduzíveis em migrations SQL versionadas por módulo em `src/main/resources/db/migration/`.

### Negativas e riscos

- **Ponto único de falha:** uma única instância do PostgreSQL atende todos os serviços. Se ela cair, o sistema inteiro para. Isso é aceitável no contexto acadêmico, e a divisão em schemas facilita separar os bancos depois.
- **Sem _joins_ entre serviços:** relatórios que cruzam dados de vários serviços (por exemplo, "corridas com tarifa social pagas no mês") precisam combinar dados via API ou eventos, em vez de uma consulta SQL única.
- **Armadilhas do JPA:** carregamento preguiçoso (_lazy loading_) e o problema de consultas N+1 podem prejudicar o desempenho se o mapeamento não for bem cuidado.
- **Disciplina de migrations e transição do `ddl-auto`:** embora o Flyway já esteja ativo, `spring.jpa.hibernate.ddl-auto=update` permanece temporariamente durante o desenvolvimento da Etapa 3; a equipe não deve editar migrations já aplicadas e deve migrar para `validate` antes de ambientes estáveis.

## Referências

- [`docs/c4/README.md`](../c4/README.md) (C4 Nível 2) e [`docs/execucao.md`](../execucao.md) (Infraestrutura com Docker Compose e Flyway)
- [`docs/c4/workspace.dsl`](../c4/workspace.dsl), container `db` e componentes `*Repository`
- [`src/main/resources/application.properties`](../../src/main/resources/application.properties)
- [`src/main/resources/db/migration/README.md`](../../src/main/resources/db/migration/README.md) e [`scripts/create-migration.sh`](../../scripts/create-migration.sh)
- [ADR 01: Adoção de SOA](./ADR-01-adocao-de-soa.md)
- [ADR 02: Event-Driven com RabbitMQ](./ADR-02-event-driven-com-rabbitmq.md)
