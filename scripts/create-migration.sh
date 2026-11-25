#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "${script_dir}/.." && pwd)"
migrations_root="${project_root}/src/main/resources/db/migration"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/create-migration.sh <modulo> <descricao>

Modulos do MobiSocial:
  users | rides | payments | notifications

Exemplo:
  ./scripts/create-migration.sh payments criar tabela payments

Resultado:
  src/main/resources/db/migration/payments/V20261124143000__criar_tabela_payments.sql
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 1
fi

module="$1"
shift
description="$*"

if [[ ! "$module" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Erro: o módulo deve conter apenas letras, números, '_' ou '-'." >&2
  exit 1
fi

description="$(printf '%s' "$description" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')"

if [[ -z "$description" ]]; then
  echo "Erro: a descrição deve conter pelo menos um caractere válido." >&2
  exit 1
fi

module_dir="${migrations_root}/${module}"
mkdir -p "$module_dir"

timestamp="$(date '+%Y%m%d%H%M%S')"
while find "$migrations_root" -type f -name "V${timestamp}__*.sql" | grep -q .; do
  sleep 1
  timestamp="$(date '+%Y%m%d%H%M%S')"
done

migration_file="${module_dir}/V${timestamp}__${description}.sql"

printf -- '-- Migration: %s\n-- Module: %s\n\n' \
  "V${timestamp}__${description}.sql" "$module" > "$migration_file"

echo "Migration criada: ${migration_file#"${project_root}/"}"
