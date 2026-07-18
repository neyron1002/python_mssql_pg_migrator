# Devcontainer para el toolkit de migracion Geus_ISP_DB (MSSQL -> PostgreSQL, 100% Python).
#
# Trae todo lo que necesita migrate.py / check_requirements.py:
#   - Python 3.12 (README pide 3.8+)
#   - unixODBC + "Microsoft ODBC Driver 18 for SQL Server"  (lo necesita pyodbc)
#   - pyodbc + psycopg[binary]                              (requirements.txt)
#   - Node.js LTS + Claude Code CLI                         (para usarlo dentro del contenedor)
#
# El repo apt de Microsoft resuelve la arquitectura solo (amd64/arm64), asi que la
# misma imagen construye tanto en Intel como en Apple Silicon (host actual: arm64).
FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

# --- unixODBC + Microsoft ODBC Driver 18 for SQL Server (para pyodbc) ---
# Nota: la imagen base trae un repo apt de yarn con la clave GPG caducada que
# rompe `apt-get update`; no lo necesitamos, asi que lo quitamos primero.
RUN set -eux; \
    rm -f /etc/apt/sources.list.d/yarn.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl gnupg ca-certificates apt-transport-https; \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg; \
    curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list \
      > /etc/apt/sources.list.d/mssql-release.list; \
    apt-get update; \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc-dev; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# --- Node.js LTS + Claude Code CLI ---
# npm global -> /usr/local/bin/claude, disponible para el usuario vscode.
# (Node lo necesita la CLI de Claude Code; el repo NodeSource resuelve amd64/arm64.)
RUN set -eux; \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    npm install -g @anthropic-ai/claude-code; \
    npm cache clean --force; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# --- Dependencias Python (baked en la imagen para arranque rapido y reproducible) ---
# El contexto de build es la raiz del repo (ver "context": ".." en devcontainer.json).
COPY migration/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /tmp/requirements.txt
