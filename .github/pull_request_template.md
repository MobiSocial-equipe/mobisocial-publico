## Descrição
<!-- Descreva brevemente o que este PR faz. Ex: Implementa o endpoint REST de agendamento de corrida (RF03) -->


## Tarefa / Requisito Relacionado
<!-- Indique qual Requisito Funcional (RF) ou ADR este PR resolve. Ex: RF01, ADR 02 -->
- Requisito/ADR: 

## Tipo de Mudança
<!-- Marque a caixa apropriada com um 'x' -->
- [ ] 🚀 Nova funcionalidade (`feat`)
- [ ] 🐛 Correção de bug (`fix`)
- [ ] 📚 Atualização de documentação (`docs`)
- [ ] ♻️ Refatoração (`refactor`)
- [ ] ⚙️ Configuração / Manutenção (`chore`)

## Como testar?
<!-- Explique como o revisor pode testar seu código. Ex: Subir o docker-compose, iniciar o Spring Boot e enviar um POST via Postman/cURL -->
1. 
2. 

## Checklist de Conformidade (Obrigatório)
<!-- Marque com 'x' após validar -->
- [ ] Os nomes de pacotes, classes e filas criados/alterados neste PR estão **exatamente iguais** aos definidos no Structurizr (C4 Níveis 2, 3 e 4).
- [ ] Se houve mudança arquitetural, a branch contém a atualização do arquivo `workspace.dsl` e da documentação correspondente em `docs/`.
- [ ] *(Se alterou o banco de dados)* Criei a migration Flyway via `./scripts/create-migration.sh <modulo> <descricao>` no schema do serviço dono (`users`, `rides`, `payments` ou `notifications`), sem FKs entre schemas (ADR 03) e sem editar migrations já aplicadas.
- [ ] *(Se adicionou/alterou variáveis de ambiente)* Atualizei `.env.example` apenas com *placeholders* (sem credenciais reais) e mantive `.env` fora do commit.
- [ ] Executei `./mvnw test` localmente e todos os testes passaram.
- [ ] Adicionei a tag `Co-authored-by` no commit (se feito em Pair Programming).