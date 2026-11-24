# Definição do Produto e Escopo — MobiSocial

[← Voltar ao README principal](../README.md) · [Arquitetura →](./arquitetura.md) · [Diagramas C4 →](./c4/README.md) · [Guia de Execução →](./execucao.md)

---

## 1. Visão Geral do Produto

O **MobiSocial** é uma plataforma de transporte e mobilidade urbana voltada para a criação de rotas inteligentes, agendamento de corridas individuais ou compartilhadas (*carpooling*), gerenciamento de passageiros e motoristas e processamento de pagamentos (incluindo rateio automático de tarifas e subsídios sociais para estudantes e pacientes em deslocamento para Unidades Básicas de Saúde e hospitais). O sistema é construído sob uma **Arquitetura Orientada a Serviços (SOA)** integrada de forma assíncrona por uma **Arquitetura Baseada em Eventos (Event-Driven)** com Spring Boot e RabbitMQ.

### Problemas Reais Solucionados

- **Otimização e Compartilhamento de Veículos (*Carpooling*):** Reduz o custo individual de deslocamento e o congestionamento urbano ao agrupar passageiros com origens, paradas e destinos compatíveis na mesma rota planejada, aproveitando a capacidade ociosa dos veículos.
- **Acesso à Educação e Saúde (Tarifa Social e Rotas Prioritárias):** Conecta estudantes universitários e pacientes de UBS/hospitais a rotas acessíveis, permitindo pagamentos simplificados com rateio solidário, PIX/cartão ou aplicação automática de desconto de tarifa social.
- **Processamento Assíncrono em Horários de Pico:** Em horários de alta demanda, o agendamento de corridas, o cálculo de divisão tarifária e o disparo de notificações ocorrem de forma desacoplada via mensageria, evitando gargalos e lentidão para passageiros e motoristas.

## 2. Catálogo de Atores e Sistemas Externos

Abaixo estão definidos os atores e os sistemas externos que interagem diretamente com o **MobiSocial**, servindo de base para o [Diagrama de Contexto (C4 Nível 1)](./c4/README.md#1-c4-nível-1-diagrama-de-contexto):

### Atores (*Persons*)

| Ator | Perfil / Papel | Principais Interações com o Sistema |
| :--- | :--- | :--- |
| **Passageiro** | Cidadão comum, Estudante ou Paciente de UBS. | Consulta rotas disponíveis, agenda corridas individuais ou compartilhadas, realiza pagamentos com rateio/tarifa social e recebe notificações da viagem. |
| **Motorista Parceiro** | Condutor credenciado ou motorista de frota urbana. | Cadastra veículo e capacidade de assentos, cria ou aceita rotas urbanas planejadas e visualiza a lista de passageiros embarcados. |

### Sistemas Externos (*External Systems*)

| Sistema Externo | Tipo | Principais Interações com o Sistema |
| :--- | :--- | :--- |
| **Gateway Externo de Pagamentos** | Sistema Externo (API REST / HTTPS) | Processa a cobrança eletrônica das corridas, rateios e validação de vouchers sociais. |
| **API de Mapas / Geolocalização** | Sistema Externo (API REST / HTTPS) | Fornece cálculo de distância em quilômetros, estimativa de tempo de percurso e traçado de rotas urbanas. |

## 3. Funcionalidades Documentadas (Requisitos Funcionais)

| Requisito | Funcionalidade | Descrição |
| :--- | :--- | :--- |
| **RF01** | **Gerenciar usuários, autenticação e veículos** | Cadastrar passageiros e motoristas no **Serviço de Usuários** (`/api/users`, `/api/auth`), realizar login com emissão de token **JWT**, definir perfis tarifários (`COMUM`, `ESTUDANTE`, `SOCIAL`) e gerenciar veículos e capacidade máxima de assentos. |
| **RF02** | **Criar e consultar rotas urbanas** | Permitir a criação e consulta de rotas (`/api/routes`) contendo ponto de partida, paradas intermediárias, destino final, horário de saída e assentos disponíveis. |
| **RF03** | **Agendar corridas e compartilhar veículos** | Receber solicitações autenticadas via API REST (`POST /api/rides`), validar o **JWT**, consultar o perfil tarifário do passageiro no **Serviço de Usuários**, consultar rotas e distâncias na **API de Mapas / Geolocalização**, parear o passageiro respeitando o limite de assentos e confirmar a reserva compartilhada. |
| **RF04** | **Processar pagamentos e rateio de tarifa** | Calcular o valor final da viagem aplicando a divisão de custos entre passageiros da mesma rota ou descontos de tarifa social e processar a transação financeira via evento assíncrono (`payments.process`) integrando com o **Gateway Externo de Pagamentos**. |
| **RF05** | **Notificar status de corridas e pagamentos** | Consumir eventos da fila `notifications.dispatch`, emitir avisos de confirmação de corrida e pagamento ao passageiro e ao motorista e registrar os envios no PostgreSQL. |

## 4. Resumo do Fluxo Principal

1. O passageiro realiza o cadastro (`POST /api/users`) e o login (`POST /api/auth/login`) no **Serviço de Usuários**, obtendo um token **JWT** e mantendo seu perfil tarifário (`COMUM`, `ESTUDANTE` ou `SOCIAL`) persistido no PostgreSQL.
2. Em seguida, o passageiro envia uma requisição HTTP autenticada (`POST /api/rides`) com o cabeçalho `Authorization: Bearer <TOKEN_JWT>` ao **Serviço de Rotas e Corridas** (também responsável pelos endpoints `/api/routes`), informando a rota desejada, se é corrida compartilhada e o método de pagamento.
3. O **Serviço de Rotas e Corridas** valida o JWT recebido, consulta via HTTP/REST o perfil tarifário do passageiro no **Serviço de Usuários**, consulta via HTTPS rotas e distâncias na **API de Mapas / Geolocalização**, verifica a disponibilidade de assentos, persiste o agendamento no PostgreSQL com status `AGUARDANDO_PAGAMENTO` e publica um evento na fila `payments.process` do RabbitMQ, liberando imediatamente a resposta HTTP.
4. O **Serviço de Pagamentos** consome o evento da fila `payments.process`, aplica a regra de rateio entre passageiros (ou desconto de tarifa social), executa a cobrança via HTTPS no **Gateway Externo de Pagamentos** e salva a transação no PostgreSQL.
5. Após aprovar a cobrança, o **Serviço de Pagamentos** publica um evento na fila `notifications.dispatch` do RabbitMQ.
6. O **Serviço de Notificações** consome o evento da fila `notifications.dispatch`, emite o aviso final de corrida e pagamento confirmado e registra os envios no PostgreSQL.

---

> Consulte também a consolidação original da disciplina em [`docs/escopo.md`](./escopo.md).
