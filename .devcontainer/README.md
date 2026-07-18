# Devcontainer — Migración `Geus_ISP_DB` (MSSQL → PostgreSQL, 100% Python)

Entorno reproducible para correr el toolkit de `migration/` (`migrate.py`,
`check_requirements.py`) sin instalar nada en el host.

## Qué trae

| Archivo | Rol |
|---|---|
| `Dockerfile` | Python 3.12 + unixODBC + **Microsoft ODBC Driver 18 for SQL Server** + `pyodbc` + `psycopg[binary]` + **Node.js LTS + Claude Code CLI** (deps horneadas en la imagen). |
| `devcontainer.json` | Se une a la red `bridge` de Docker, corre el resolver de IPs y verifica prerrequisitos. |
| `host-resolve-db-ips.sh` | `initializeCommand` (corre en el **host**): resuelve las IPs actuales de los contenedores de BD y las escribe en `migration/.env`. |

## Cómo conecta con las bases

Los contenedores de BD (`geus_mssql_2022`, `geus-postgres`) viven en la red
**`bridge`** por defecto de Docker. El devcontainer:

1. Se **une a esa misma red** (`"runArgs": ["--network=bridge"]`), y
2. Los alcanza por su **IP del bridge** (p. ej. `172.17.0.3` / `172.17.0.4`).

> **Por qué IP del bridge y no `host.docker.internal`:** PostgreSQL funciona por
> ambas rutas, pero MSSQL (protocolo TDS) **se cuelga** vía `host.docker.internal`
> en Docker Desktop; por la IP del bridge, no.

Las IPs del bridge **no son estables** entre reinicios, así que
`host-resolve-db-ips.sh` corre en cada arranque (antes de crear el contenedor) y
refresca `MSSQL_HOST` / `PG_HOST` en `migration/.env`, **sin tocar las
credenciales** ni el resto del archivo. Si `migration/.env` no existe, lo siembra
desde `.env.example` (quedan credenciales por editar).

Overrides opcionales (variables de entorno del host al abrir el devcontainer):
`MSSQL_CONTAINER`, `PG_CONTAINER`, `DB_BRIDGE_NETWORK`.

## Uso

1. **Abrir en el devcontainer** — VS Code: *Dev Containers: Reopen in Container*.
   Requiere que los contenedores `geus_mssql_2022` y `geus-postgres` estén
   corriendo en el host.
2. Al crearse, corre `check_requirements.py` automáticamente. Para además probar
   la conectividad viva a ambas BD:

   ```bash
   python migration/check_requirements.py --connect
   ```

3. **Migrar** (las dependencias ya están instaladas; se corre con el `python` del
   contenedor, sin `.venv`):

   ```bash
   cd migration
   python migrate.py --all               # esquema + datos + validación
   python migrate.py --schema --fresh    # DROP+CREATE de la base PG + DDL
   python migrate.py --data              # solo copiar datos + secuencias
   python migrate.py --validate          # solo validar
   ```

> El `README.md` de `migration/` usa `.venv/bin/python …`; **dentro del
> devcontainer no hace falta el venv** — el contenedor ya es el aislamiento, así
> que se invoca `python …` directamente.

## Claude Code

`claude` (Claude Code CLI) viene instalado y en el `PATH`. Úsalo dentro del
contenedor:

```bash
claude          # sesión interactiva
claude --version
```

La **primera vez** hay que autenticarse (`claude` abre el login). La sesión se
guarda en `~/.claude` del contenedor, así que **persiste entre reinicios** del
devcontainer; una **reconstrucción** de la imagen (cambia el `Dockerfile`) sí
pide volver a entrar. Para que la auth sobreviva también a las reconstrucciones,
monta `~/.claude` en un volumen agregando a `devcontainer.json`:

```jsonc
"mounts": [
  "source=geus-claude-config,target=/home/vscode/.claude,type=volume"
]
```

## Notas

- **Arquitectura:** el repo apt de Microsoft resuelve amd64/arm64 solo, así que la
  imagen construye igual en Intel y en Apple Silicon.
- **Credenciales:** `migration/.env` está gitignorado (contiene secretos); el
  resolver de IPs preserva lo que ya tengas ahí.
- El aviso `[--] venv` de `check_requirements.py` es esperado y no es crítico
  (instalamos en el Python global del contenedor).
