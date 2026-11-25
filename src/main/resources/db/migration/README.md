# Migrations Flyway

As migrations versionadas devem usar timestamp no formato `yyyyMMddHHmmss`:

```text
V20261124143000__criar_tabela_payments.sql
```

As migrations podem ser agrupadas por módulo (um subdiretório por serviço SOA) dentro de `src/main/resources/db/migration`:

```text
db/migration/
├── V20261125134217__init_schemas.sql
├── users/
├── rides/
├── payments/
└── notifications/
```

As versões devem ser únicas entre todos os módulos, pois o Flyway varre `classpath:db/migration` recursivamente (`spring.flyway.locations=classpath:db/migration`).

Script executável criado em [`scripts/create-migration.sh`](../../../../../scripts/create-migration.sh).

## Uso

```bash
./scripts/create-migration.sh payments criar tabela payments
```

Gera automaticamente:

```text
src/main/resources/db/migration/payments/V20261124143000__criar_tabela_payments.sql
```

O script também normaliza a descrição, cria a pasta do módulo e evita colisões globais de timestamp entre os diretórios. Para exibir a ajuda do script, execute:

```bash
./scripts/create-migration.sh --help
```

## Regras de Schema (ADR 03)

- Qualifique explicitamente o schema do serviço dono da tabela (ex.: `CREATE TABLE payments.payments (...)`), em conformidade com o [ADR 03](../../../../../docs/adr/ADR-03-persistencia-postgresql-jpa.md).
- Não crie chaves estrangeiras (*foreign keys*) cruzando schemas de serviços distintos.
- Nunca edite uma migration que já foi aplicada ou versionada; para alterar uma tabela existente, gere uma nova migration.
