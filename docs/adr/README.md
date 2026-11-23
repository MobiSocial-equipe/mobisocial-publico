# Decisões Arquiteturais (ADRs) do MobiSocial

Esta pasta registra as principais decisões arquiteturais do MobiSocial no formato **ADR (Architecture Decision Record)**. Cada ADR descreve o contexto, a decisão tomada, as alternativas consideradas e as consequências (positivas e negativas).

| ADR                                               | Título                                                                       | Status | Data       |
| :------------------------------------------------ | :--------------------------------------------------------------------------- | :----- | :--------- |
| [ADR 01](./ADR-01-adocao-de-soa.md)               | Adoção de Arquitetura Orientada a Serviços (SOA) para separação dos serviços | Aceito | 23/11/2026 |
| [ADR 02](./ADR-02-event-driven-com-rabbitmq.md)   | Arquitetura Event-Driven com RabbitMQ para pagamentos e notificações         | Aceito | 23/11/2026 |
| [ADR 03](./ADR-03-persistencia-postgresql-jpa.md) | Persistência relacional com PostgreSQL e Spring Data JPA                     | Aceito | 23/11/2026 |

## Como criar um novo ADR

1. Crie o arquivo `ADR-NN-titulo-curto.md` nesta pasta, seguindo a numeração.
2. Use as seções: **Status**, **Contexto**, **Decisão**, **Alternativas consideradas**, **Consequências** e **Referências**.
3. Se uma decisão for substituída, não apague o ADR antigo: mude o status para `Substituído pelo ADR NN` e crie o novo.
4. Adicione o ADR na tabela acima e abra o Pull Request seguindo o [`CONTRIBUTING.md`](../CONTRIBUTING.md) (ex.: `docs: documenta ADR 04 sobre ...`).
