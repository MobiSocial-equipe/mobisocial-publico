# MobiSocial: Transporte e Mobilidade Urbana Inclusiva

[![Java](https://img.shields.io/badge/Java-17%2B-orange)](#início-rápido)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-4.1.2-brightgreen)](./pom.xml)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)](./docker-compose.yml)
[![RabbitMQ](https://img.shields.io/badge/RabbitMQ-4%20(AMQP)-ff6600)](./docker-compose.yml)
[![Flyway](https://img.shields.io/badge/Flyway-Migrations-cc0200)](./src/main/resources/db/migration/README.md)
[![C4 Model](https://img.shields.io/badge/C4%20Model-Structurizr-1f6feb)](./docs/c4/README.md)

Plataforma de mobilidade urbana voltada à criação de rotas inteligentes, agendamento de corridas compartilhadas (*carpooling*), gestão de usuários/veículos e processamento assíncrono de pagamentos com rateio e tarifas sociais (estudantes e pacientes de UBS/hospitais). Construída em **Arquitetura Orientada a Serviços (SOA)** integrada via **Event-Driven Architecture** (Spring Boot, RabbitMQ, PostgreSQL e Flyway) e documentada com **C4 Model (Structurizr)** e **ADRs**.

---

## Mapa da Documentação

| Módulo | Conteúdo | Documento |
| :--- | :--- | :--- |
| **Produto e Escopo** | Visão geral, problemas reais, atores, sistemas externos, RF01–RF05 e fluxo principal | [`docs/produto.md`](./docs/produto.md) |
| **Arquitetura e Estilos** | Decisão de SOA + Event-Driven, responsabilidades dos 4 serviços e mapa canônico | [`docs/arquitetura.md`](./docs/arquitetura.md) |
| **Diagramas C4 (Structurizr + Mermaid)** | Visões Nível 1 (Contexto), Nível 2 (Containers + Fluxos), Nível 3 (Componentes) e Nível 4 (Classes) | [`docs/c4/README.md`](./docs/c4/README.md) |
| **Decisões Arquiteturais (ADRs)** | ADRs 01 (SOA), 02 (Event-Driven com RabbitMQ) e 03 (PostgreSQL, JPA e Flyway) | [`docs/adr/README.md`](./docs/adr/README.md) |
| **Guia de Execução** | Configuração do `.env`, Docker Compose, testes e `curl` do fluxo principal | [`docs/execucao.md`](./docs/execucao.md) |
| **Migrations Flyway** | Convenção `yyyyMMddHHmmss`, estrutura por módulo e uso do `./scripts/create-migration.sh` | [`src/main/resources/db/migration/README.md`](./src/main/resources/db/migration/README.md) |
| **Cronograma e Equipe** | Divisão por duplas (Equipe 10) e entregáveis das Etapas 1, 2 e 3 | [`docs/cronograma.md`](./docs/cronograma.md) |
| **Guia de Contribuição** | Git Flow, Conventional Commits, Pair Programming e regra de conformidade C4 | [`docs/CONTRIBUTING.md`](./docs/CONTRIBUTING.md) |
| **Escopo Base da Disciplina** | Especificação consolidada do Tema 13 | [`docs/escopo.md`](./docs/escopo.md) |

---

## Visão Geral da Arquitetura (C4 Nível 1)

<details open>
<summary>Expandir / recolher Diagrama de Contexto (Structurizr)</summary>

![Diagrama de Contexto - C4 Nível 1](docs/c4/.structurizr/1/svgs/N1-Contexto-dark.svg)

</details>

> Veja todos os níveis do C4 (Containers, Fluxos Dinâmicos `N4-1` a `N4-4`, Componentes `N3-*` e Diagramas de Classes) em [`docs/c4/README.md`](./docs/c4/README.md) ou abra diretamente [`docs/c4/workspace.dsl`](./docs/c4/workspace.dsl).

### Serviços SOA & Mensageria AMQP

| Serviço / Infra | Pacote / Recurso | Responsabilidade Principal |
| :--- | :--- | :--- |
| **Serviço de Usuários** | `...mobisocial.user` · schema `users` | Cadastro de passageiros/motoristas, veículos, login JWT e perfis tarifários (`COMMON`, `STUDENT`, `SOCIAL`) |
| **Serviço de Rotas e Corridas** | `...mobisocial.ride` · schema `rides` | Gestão de rotas (`/api/routes`), agendamento compartilhado (`/api/rides`) e publicação em `payments.process` |
| **Serviço de Pagamentos** | `...mobisocial.payment` · schema `payments` | Consumo de `payments.process`, cálculo de rateio/subsídio social, cobrança no gateway e publicação em `notifications.dispatch` |
| **Serviço de Notificações** | `...mobisocial.notification` · schema `notifications` | Consumo de `notifications.dispatch`, emissão de confirmações e histórico no PostgreSQL |
| **RabbitMQ + PostgreSQL** | [`docker-compose.yml`](./docker-compose.yml) | Filas duráveis (`payments.process`, `notifications.dispatch` + DLQs) e banco relacional com schemas isolados via Flyway |

---

## Início Rápido

```bash
# 1. Crie o arquivo .env local a partir do modelo (preencha com seus valores)
cp .env.example .env

# 2. Suba PostgreSQL (porta 5433) e RabbitMQ (portas 5672 / 15672)
docker compose up -d

# 3. Execute os testes e suba a aplicação Spring Boot (aplica migrations Flyway automaticamente)
./mvnw test
./mvnw spring-boot:run
```

Para configurar detalhes de ambiente, criar novas migrations SQL (`./scripts/create-migration.sh`) ou testar os endpoints REST (`POST /api/users`, `POST /api/auth/login`, `POST /api/rides`), acesse o [**Guia Completo de Execução**](./docs/execucao.md).

---

## Equipe 10 — UFC Quixadá

**Integrantes:** Felipe Maia e Clidenor (**Dupla A**) · Pablo e Maria José (**Dupla B**) · Cauan Ricardo e João Vitor (**Dupla C**) — consulte as entregas completas em [`docs/cronograma.md`](./docs/cronograma.md).
