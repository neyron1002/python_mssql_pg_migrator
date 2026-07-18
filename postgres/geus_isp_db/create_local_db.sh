#!/usr/bin/env bash
# =====================================================================
# Geus_ISP_DB  ·  create_local_db.sh  ·  Turnkey local/test DB creation
# =====================================================================
# Crea Geus_ISP_DB y aplica el DDL completo (00..03) para un entorno de
# PRUEBA LOCAL, reproduciendo el mismo entorno que usa la suite de
# integración (postgres:18, locale ICU es-ES).
#
# Dos modos:
#
#   --docker  (por defecto)  Levanta un contenedor postgres:18 inicializado
#                            con ICU es-ES (igual que PostgresIspDbFixture),
#                            aplica el DDL y deja el contenedor corriendo.
#                            No requiere psql en el host, solo Docker.
#
#   --local                  Usa un servidor PostgreSQL ya existente vía el
#                            psql del host y variables PG* estándar
#                            (PGHOST/PGPORT/PGUSER/PGPASSWORD).
#
# Uso:
#   ./create_local_db.sh                 # Docker (turnkey)
#   ./create_local_db.sh --local         # contra un PG existente (usa PG*)
#   PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres \
#       ./create_local_db.sh --local
#
# Config del modo Docker (override por env):
#   IMAGE=postgres:18  CONTAINER=geus-isp-pg  HOST_PORT=5432  PG_PASSWORD=postgres
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:---docker}"

IMAGE="${IMAGE:-postgres:18}"
CONTAINER="${CONTAINER:-geus-isp-pg}"
HOST_PORT="${HOST_PORT:-5432}"
PG_PASSWORD="${PG_PASSWORD:-postgres}"

apply_local() {
  # Requiere psql en el host + variables PG* apuntando al servidor destino.
  if ! command -v psql >/dev/null 2>&1; then
    echo "ERROR: 'psql' no está en el PATH. Usa el modo --docker o instala postgresql-client." >&2
    exit 1
  fi
  echo ">> Aplicando DDL con psql del host contra ${PGHOST:-localhost}:${PGPORT:-5432} (db 'postgres')..."
  psql -v ON_ERROR_STOP=1 -d "${PGDATABASE:-postgres}" -f "${SCRIPT_DIR}/create_local_db.sql"
  echo ">> Listo. Base 'Geus_ISP_DB' creada."
}

apply_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: 'docker' no está disponible. Usa el modo --local contra un PG existente." >&2
    exit 1
  fi

  # Contenedor limpio: si ya existe uno con este nombre, se elimina.
  if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
    echo ">> Eliminando contenedor previo '${CONTAINER}'..."
    docker rm -f "${CONTAINER}" >/dev/null
  fi

  echo ">> Levantando ${IMAGE} como '${CONTAINER}' (ICU es-ES) en el puerto ${HOST_PORT}..."
  # Cluster inicializado con ICU es-ES (idéntico al fixture de integración).
  # POSTGRES_DB=postgres: NO auto-creamos Geus_ISP_DB; la crea el bootstrap
  # SQL, ejercitando el camino de creación manual de la base.
  docker run -d --name "${CONTAINER}" \
    -e POSTGRES_PASSWORD="${PG_PASSWORD}" \
    -e POSTGRES_DB=postgres \
    -e POSTGRES_INITDB_ARGS="--locale-provider=icu --icu-locale=es-ES" \
    -p "${HOST_PORT}:5432" \
    -v "${SCRIPT_DIR}:/ddl:ro" \
    "${IMAGE}" >/dev/null

  echo ">> Esperando a que PostgreSQL acepte conexiones..."
  # Chequeo por TCP (-h 127.0.0.1): durante initdb el entrypoint corre un
  # servidor TEMPORAL que escucha SOLO en el socket Unix. Verificar el puerto
  # TCP evita ese falso positivo y solo pasa cuando el servidor FINAL arrancó.
  ready=0
  for _ in $(seq 1 90); do
    if docker exec "${CONTAINER}" pg_isready -h 127.0.0.1 -p 5432 -U postgres >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done
  if [ "${ready}" -ne 1 ]; then
    echo "ERROR: el contenedor no quedó listo a tiempo. Logs:" >&2
    docker logs --tail 30 "${CONTAINER}" >&2 || true
    exit 1
  fi

  echo ">> Aplicando DDL (00..03) dentro del contenedor..."
  # \ir en create_local_db.sql resuelve relativo a /ddl (los archivos montados).
  docker exec "${CONTAINER}" \
    psql -v ON_ERROR_STOP=1 -U postgres -d postgres -f /ddl/create_local_db.sql

  echo ""
  echo ">> Listo. Base 'Geus_ISP_DB' creada en el contenedor '${CONTAINER}'."
  echo "   Conexión: postgresql://postgres:${PG_PASSWORD}@localhost:${HOST_PORT}/Geus_ISP_DB"
  echo "   Consola : docker exec -it ${CONTAINER} psql -U postgres -d Geus_ISP_DB"
  echo "   Detener : docker rm -f ${CONTAINER}"
}

case "${MODE}" in
  --docker) apply_docker ;;
  --local)  apply_local ;;
  -h|--help)
    grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//'
    ;;
  *)
    echo "Modo desconocido: '${MODE}'. Usa --docker (por defecto), --local o --help." >&2
    exit 1
    ;;
esac
