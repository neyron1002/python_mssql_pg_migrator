#!/usr/bin/env bash
# host-resolve-db-ips.sh - initializeCommand del devcontainer (corre en el HOST).
#
# Los contenedores de BD (geus_mssql_2022, geus-postgres) viven en la red bridge
# por defecto de Docker. El devcontainer se une a esa misma red y los alcanza por
# su IP del bridge -- pero esas IPs NO son estables entre reinicios. Este script
# resuelve las IPs actuales y las escribe en migration/.env (solo las lineas
# MSSQL_HOST / PG_HOST; NO toca credenciales ni el resto del archivo) antes de
# que el contenedor arranque.
#
# Overrides por entorno: MSSQL_CONTAINER, PG_CONTAINER, DB_BRIDGE_NETWORK.
# Es best-effort: si Docker no esta o algun contenedor no corre, avisa y sale 0
# (deja el .env como estaba) para no abortar el arranque del devcontainer.
set -euo pipefail

MSSQL_CONTAINER="${MSSQL_CONTAINER:-geus_mssql_2022}"
PG_CONTAINER="${PG_CONTAINER:-geus-postgres}"
NETWORK="${DB_BRIDGE_NETWORK:-bridge}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../migration/.env"
ENV_EXAMPLE="$HERE/../migration/.env.example"

warn() { printf '[host-resolve-db-ips] %s\n' "$*" >&2; }

if ! command -v docker >/dev/null 2>&1; then
  warn "docker no esta en el PATH del host; dejo migration/.env sin cambios."
  exit 0
fi

# Si aun no hay .env, lo sembramos desde el ejemplo (credenciales quedan por editar).
if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  warn "migration/.env no existia: lo cree desde .env.example (edite credenciales)."
fi
if [ ! -f "$ENV_FILE" ]; then
  warn "no encuentro migration/.env ni .env.example; nada que actualizar."
  exit 0
fi

ip_of() {
  # IP del contenedor $1 dentro de la red $NETWORK (vacio si no aplica).
  docker inspect -f "{{ with index .NetworkSettings.Networks \"$NETWORK\" }}{{ .IPAddress }}{{ end }}" "$1" 2>/dev/null || true
}

MSSQL_IP="$(ip_of "$MSSQL_CONTAINER")"
PG_IP="$(ip_of "$PG_CONTAINER")"

[ -n "$MSSQL_IP" ] && warn "MSSQL ($MSSQL_CONTAINER) -> $MSSQL_IP" \
  || warn "no pude resolver la IP de $MSSQL_CONTAINER en la red '$NETWORK'; conservo el valor previo."
[ -n "$PG_IP" ] && warn "PostgreSQL ($PG_CONTAINER) -> $PG_IP" \
  || warn "no pude resolver la IP de $PG_CONTAINER en la red '$NETWORK'; conservo el valor previo."

# Reescribe SOLO las lineas de host que si pudimos resolver; el resto intacto.
updated="$(awk -v ms="$MSSQL_IP" -v pg="$PG_IP" '
  /^MSSQL_HOST=/ && ms != "" { print "MSSQL_HOST=" ms; next }
  /^PG_HOST=/    && pg != "" { print "PG_HOST=" pg; next }
  { print }
' "$ENV_FILE")"
printf '%s\n' "$updated" > "$ENV_FILE"

exit 0
