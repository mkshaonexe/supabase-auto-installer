#!/usr/bin/env bash

# 🚀 SUPER EASY SUPABASE AUTO-INSTALLER 🚀
# Fully automated Supabase + Docker Compose stack with robust error handling.

set -Eeuo pipefail
set -o errtrace
trap 'error_handler $LINENO' ERR
trap 'cleanup' EXIT

# -------------------------
# GLOBAL VARIABLES & LOGGING
# -------------------------
LOG_FILE="/var/log/supabase-installer.log"
INSTALL_DIR="/opt/supabase"
BACKUP_DIR=""
MAIN_DOMAIN=""
API_DOMAIN=""
STUDIO_DOMAIN=""
USER_EMAIL=""
POSTGRES_PASSWORD=""
JWT_SECRET=""
SUPABASE_ANON_KEY=""
SUPABASE_SERVICE_ROLE_KEY=""
IMGPROXY_KEY=""
IMGPROXY_SALT=""

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; PURPLE='\033[0;35m'; NC='\033[0m'

error_handler() {
  local lineno=$1
  echo -e "${RED}❌ Error on or near line ${lineno}. Check ${LOG_FILE} for details.${NC}"
  exit 1
}

cleanup() {
  echo "🔄 Cleaning up temporary files…" >> "$LOG_FILE" || true
  # (Any other cleanup actions)
}

print_message() {
  local color=$1; local emoji=$2; local message=$3
  echo -e "${color}${emoji} ${message}${NC}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ${emoji} ${message}" >> "$LOG_FILE"
}

# -------------------------
# REQUIREMENTS CHECK
# -------------------------
check_root() {
  if (( EUID != 0 )); then
    echo "⚠️  Please run as root or with sudo."
    exit 1
  fi
}

check_ubuntu_version() {
  local version
  version=$(lsb_release -rs)
  if ! dpkg --compare-versions "$version" ge "18.04"; then
    echo "⚠️  Ubuntu 18.04 or newer is required (found ${version})."
    exit 1
  fi
}

install_prereqs() {
  print_message "$CYAN" "🔧" "Installing Docker and other prerequisites…"
  apt-get update -y >>"$LOG_FILE" 2>&1
  apt-get install -y \
    apt-transport-https ca-certificates curl gnupg lsb-release \
    docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    bc >>"$LOG_FILE" 2>&1

  # Add Docker GPG key & repo (if not already)
  if ! apt-key list | grep -q "Docker"; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - >>"$LOG_FILE" 2>&1
    add-apt-repository \
      "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" >>"$LOG_FILE" 2>&1
    apt-get update -y >>"$LOG_FILE" 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io >>"$LOG_FILE" 2>&1
  fi

  # Ensure docker-compose CLI is available
  if ! command -v docker-compose &>/dev/null; then
    ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
  fi
}

configure_user() {
  print_message "$CYAN" "👤" "Adding $SUDO_USER to docker group…"
  usermod -aG docker "${SUDO_USER:-$USER}" >>"$LOG_FILE" 2>&1 || true
  echo "ℹ️  You may need to log out and back in (or run 'newgrp docker') for this to take effect."
}

# -------------------------
# DOMAIN & SECRET SETUP
# -------------------------
sanitize_domain() {
  # strip https://, http://, and www.
  MAIN_DOMAIN=${MAIN_DOMAIN#https://}
  MAIN_DOMAIN=${MAIN_DOMAIN#http://}
  MAIN_DOMAIN=${MAIN_DOMAIN#www.}
}

generate_secrets() {
  print_message "$CYAN" "🔐" "Generating secrets…"
  POSTGRES_PASSWORD=$(openssl rand -base64 32)
  JWT_SECRET=$(openssl rand -base64 32)
  SUPABASE_ANON_KEY=$(openssl rand -base64 32)
  SUPABASE_SERVICE_ROLE_KEY=$(openssl rand -base64 32)
  IMGPROXY_KEY=$(openssl rand -base64 32)
  IMGPROXY_SALT=$(openssl rand -base64 32)
}

backup_existing() {
  if docker ps -q &>/dev/null; then
    print_message "$YELLOW" "💾" "Stopping existing containers…"
    docker stop $(docker ps -q) >>"$LOG_FILE" 2>&1 || true
    BACKUP_DIR="$(mktemp -d)"
    cp "${INSTALL_DIR}/docker-compose.yml" "${BACKUP_DIR}/" || true
    print_message "$GREEN" "✅" "Backed up old compose file to ${BACKUP_DIR}"
  fi
}

# -------------------------
# GENERATE docker-compose.yml
# -------------------------
generate_compose() {
  mkdir -p "${INSTALL_DIR}/volumes"
  cat > "${INSTALL_DIR}/docker-compose.yml" <<EOF
version: "3.9"

networks:
  supabase:

services:
  # Postgres
  db:
    image: supabase/postgres:15.1.0.117
    container_name: supabase-db
    restart: unless-stopped
    networks:
      - supabase
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD}"
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 30s
      timeout: 10s
      retries: 5

  # API (PostgREST)
  rest:
    image: supabase/postgrest:v11.0.1
    depends_on:
      db:
        condition: service_healthy
    networks:
      - supabase
    ports:
      - "3000:3000"
    environment:
      PGRST_DB_URI: "postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres"
      PGRST_JWT_SECRET: "${JWT_SECRET}"
      PGRST_DB_ANON_ROLE: "anon"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Auth (GoTrue)
  auth:
    image: supabase/gotrue:v2.64.0
    depends_on:
      db:
        condition: service_healthy
      rest:
        condition: service_started
    networks:
      - supabase
    ports:
      - "9999:9999"
    environment:
      GOTRUE_DB_DRIVER: "postgres"
      GOTRUE_DB_DATABASE_URL: "postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres"
      GOTRUE_JWT_SECRET: "${JWT_SECRET}"
      GOTRUE_SITE_URL: "https://${MAIN_DOMAIN}"
      GOTRUE_URI_ALLOW_LIST: "https://${MAIN_DOMAIN}"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9999/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Storage
  storage:
    image: supabase/storage-api:v0.40.4
    depends_on:
      db:
        condition: service_healthy
      rest:
        condition: service_started
    networks:
      - supabase
    ports:
      - "5000:5000"
    environment:
      ANON_KEY: "${SUPABASE_ANON_KEY}"
      SERVICE_KEY: "${SUPABASE_SERVICE_ROLE_KEY}"
      POSTGREST_URL: "http://rest:3000"
      PGRST_JWT_SECRET: "${JWT_SECRET}"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Realtime
  realtime:
    image: supabase/realtime:v0.28.3
    depends_on:
      db:
        condition: service_healthy
    networks:
      - supabase
    ports:
      - "4000:4000"
    environment:
      DB_HOST: db
      DB_NAME: postgres
      DB_USER: postgres
      DB_PASSWORD: "${POSTGRES_PASSWORD}"
      PORT: 4000
      JWT_SECRET: "${JWT_SECRET}"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Studio
  studio:
    image: supabase/studio:latest
    depends_on:
      auth:
        condition: service_healthy
    networks:
      - supabase
    ports:
      - "3000:3000"
    environment:
      STUDIO_API_URL: "http://rest:3000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Imgproxy
  imgproxy:
    image: darthsim/imgproxy:v3.8.0
    networks:
      - supabase
    ports:
      - "5001:5001"
    environment:
      IMGPROXY_BIND: ":5001"
      IMGPROXY_LOCAL_FILESYSTEM_ROOT: "/"
      IMGPROXY_KEY: "${IMGPROXY_KEY}"
      IMGPROXY_SALT: "${IMGPROXY_SALT}"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Kong API Gateway
  kong:
    image: kong:3.0
    networks:
      - supabase
    ports:
      - "8000:8000"
      - "8443:8443"
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: "/etc/kong/kong.yml"
    volumes:
      - ./volumes/api/kong.yml:/etc/kong/kong.yml:ro
    healthcheck:
      test: ["CMD", "kong health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Vector (optional logging)
  vector:
    image: timberio/vector:0.28.1-alpine
    networks:
      - supabase
    volumes:
      - ./volumes/logs/vector.yml:/etc/vector/vector.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    healthcheck:
      test: ["CMD", "vector validate /etc/vector/vector.yml"]
      interval: 30s
      timeout: 10s
      retries: 3

EOF
}

# -------------------------
# DEPLOY
# -------------------------
deploy() {
  print_message "$CYAN" "🚢" "Deploying Supabase stack…"
  pushd "$INSTALL_DIR" >/dev/null
  docker-compose pull >>"$LOG_FILE" 2>&1
  docker-compose up -d >>"$LOG_FILE" 2>&1
  print_message "$GREEN" "✅" "Supabase services are starting. Attach to logs with 'docker-compose logs -f'."
  popd >/dev/null
}

# -------------------------
# MAIN
# -------------------------
main() {
  check_root
  check_ubuntu_version
  install_prereqs
  configure_user

  read -rp "Enter your main domain (e.g. example.com): " MAIN_DOMAIN
  sanitize_domain

  generate_secrets
  backup_existing
  generate_compose
  deploy
}

main "$@"
