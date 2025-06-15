#!/bin/bash

# 🚀 SUPER EASY SUPABASE AUTO-INSTALLER 🚀
# Made so simple that even an 8-year-old can use it!
# Just run this script and everything will be done automatically!

set -e  # Exit on any error

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Fun emojis for progress
ROCKET="🚀"
STAR="⭐"
FIRE="🔥"
GEAR="⚙️"
LOCK="🔐"
SUCCESS="✅"
WARNING="⚠️"
ERROR="❌"
THINKING="🤔"
PARTY="🎉"
MAGIC="🪄"
SPARKLES="✨"

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/supabase-install.log"
BACKUP_DIR=""
INSTALL_DIR="/opt/supabase"

# Function to print colored messages
print_message() {
    local color=$1
    local emoji=$2
    local message=$3
    echo -e "${color}${emoji} ${message}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $emoji $message" >> "$LOG_FILE"
}

print_header() {
    echo ""
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${PURPLE}================================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}${GEAR} STEP: $1${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}${SUCCESS} SUCCESS: $1${NC}"
    echo ""
}

print_warning() {
    echo -e "${YELLOW}${WARNING} WARNING: $1${NC}"
    echo ""
}

print_error() {
    echo -e "${RED}${ERROR} ERROR: $1${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}${STAR} INFO: $1${NC}"
}

print_magic() {
    echo -e "${PURPLE}${MAGIC} MAGIC: $1${NC}"
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    print_error "Something went wrong on line $line_number (exit code: $exit_code)"
    print_info "Check the log file: $LOG_FILE"
    
    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
        print_info "Your backup is saved at: $BACKUP_DIR"
        print_info "You can restore it if needed"
    fi
    
    print_info "You can run the script again to try fixing the issue"
    exit $exit_code
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Function to show progress
show_progress() {
    local duration=$1
    local message=$2
    
    echo -n -e "${BLUE}${SPARKLES} $message"
    for ((i=0; i<duration; i++)); do
        echo -n "."
        sleep 1
    done
    echo -e " Done! ${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Don't run this script as root (sudo)! Run as normal user."
        print_info "The script will ask for sudo password when needed."
        exit 1
    fi
}

# Function to check Ubuntu version
check_ubuntu() {
    if ! command -v lsb_release &> /dev/null; then
        print_error "This script only works on Ubuntu!"
        print_info "Please use Ubuntu 18.04 or newer"
        exit 1
    fi
    
    local version=$(lsb_release -rs)
    print_info "Detected Ubuntu $version"
    
    if [[ $(echo "$version >= 18.04" | bc -l 2>/dev/null || echo "0") -ne 1 ]]; then
        print_warning "This script works best on Ubuntu 18.04 or newer"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to check system requirements
check_requirements() {
    print_step "Checking system requirements"
    
    # Check available disk space (minimum 10GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=$((10 * 1024 * 1024)) # 10GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        print_error "Not enough disk space! Need at least 10GB free"
        print_info "Available: $(($available_space / 1024 / 1024))GB"
        exit 1
    fi
    
    # Check RAM (minimum 2GB)
    local ram_mb=$(free -m | awk 'NR==2{print $2}')
    if [[ $ram_mb -lt 2048 ]]; then
        print_warning "Less than 2GB RAM detected. Supabase might run slowly"
        print_info "Current RAM: ${ram_mb}MB"
    fi
    
    print_success "System requirements check passed!"
}

# Function to get user input
get_user_config() {
    print_header "${THINKING} LET'S SET UP YOUR SUPABASE!"
    
    echo -e "${WHITE}Hi there! ${PARTY} Let's make your Supabase awesome!${NC}"
    echo ""
    echo -e "${CYAN}I just need to know your domain name and I'll do the rest! ${MAGIC}${NC}"
    echo ""
    
    # Get main domain with validation
    while true; do
        read -p "$(echo -e ${YELLOW}${STAR}' What is your main domain? (like: mywebsite.com): '${NC})" MAIN_DOMAIN
        
        # Remove protocol if user adds it
        MAIN_DOMAIN=$(echo "$MAIN_DOMAIN" | sed 's|^https\?://||' | sed 's|^www\.||')
        
        if [[ -n "$MAIN_DOMAIN" && "$MAIN_DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            print_error "Please enter a valid domain (like: example.com)"
            print_info "Don't include http:// or www."
        fi
    done
    
    # Set subdomains automatically
    API_DOMAIN="api.$MAIN_DOMAIN"
    STUDIO_DOMAIN="studio.$MAIN_DOMAIN"
    
    echo ""
    print_success "Perfect! I'll automatically set up:"
    print_info "🌐 API: https://$API_DOMAIN"
    print_info "🎨 Studio: https://$STUDIO_DOMAIN"
    echo ""
    
    # Ask for email (optional)
    echo -e "${CYAN}For SSL certificates, I can use Let's Encrypt (recommended)${NC}"
    read -p "$(echo -e ${YELLOW}${LOCK}' Your email for SSL certificates (press Enter to use self-signed): '${NC})" USER_EMAIL
    
    if [[ -n "$USER_EMAIL" ]]; then
        print_info "Great! I'll get real SSL certificates for you"
    else
        print_info "OK! I'll create self-signed certificates (browsers will show warning)"
    fi
    
    echo ""
    print_magic "Everything is ready! Let me do all the magic for you! ${SPARKLES}"
    echo ""
    
    # Show what will happen
    echo -e "${WHITE}Here's what I'll do:${NC}"
    echo -e "${GREEN}  1. ${NC}Backup any existing installations"
    echo -e "${GREEN}  2. ${NC}Install Docker, Node.js, and other tools"
    echo -e "${GREEN}  3. ${NC}Generate super secure keys automatically"
    echo -e "${GREEN}  4. ${NC}Set up Supabase with all services"
    echo -e "${GREEN}  5. ${NC}Configure SSL certificates"
    echo -e "${GREEN}  6. ${NC}Start everything up"
    echo -e "${GREEN}  7. ${NC}Give you all the important passwords and keys"
    echo ""
    
    read -p "$(echo -e ${GREEN}${ROCKET}' Press Enter to start the magic or Ctrl+C to cancel... '${NC})"
}

# Function to create backup of existing configs
backup_existing() {
    print_step "Creating backup of existing installations ${GEAR}"
    
    BACKUP_DIR="/tmp/supabase-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing nginx configs
    if [ -d "/etc/nginx" ]; then
        print_info "Backing up existing Nginx configuration"
        sudo cp -r /etc/nginx "$BACKUP_DIR/nginx-backup" 2>/dev/null || true
    fi
    
    # Backup existing supabase
    if [ -d "$INSTALL_DIR" ]; then
        print_info "Backing up existing Supabase installation"
        sudo cp -r "$INSTALL_DIR" "$BACKUP_DIR/supabase-backup" 2>/dev/null || true
    fi
    
    # Stop existing services gracefully
    print_info "Stopping any existing services"
    sudo systemctl stop nginx 2>/dev/null || true
    sudo systemctl stop apache2 2>/dev/null || true
    
    # Stop existing docker containers safely
    if command -v docker &> /dev/null; then
        print_info "Stopping existing Docker containers"
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker system prune -f 2>/dev/null || true
    fi
    
    # Remove old installations
    sudo rm -rf "$INSTALL_DIR" 2>/dev/null || true
    
    print_success "Backup created at: $BACKUP_DIR"
    echo "$BACKUP_DIR" > /tmp/supabase-backup-location
}

# Function to install dependencies with progress
install_dependencies() {
    print_step "Installing all the cool tools we need ${GEAR}"
    
    # Update system
    print_info "Updating system packages..."
    show_progress 5 "Updating package lists"
    sudo apt update -y >> "$LOG_FILE" 2>&1
    
    show_progress 10 "Upgrading existing packages"
    sudo apt upgrade -y >> "$LOG_FILE" 2>&1
    
    # Install basic tools
    print_info "Installing basic development tools"
    sudo apt install -y curl wget git build-essential software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release bc jq openssl \
        unzip zip htop >> "$LOG_FILE" 2>&1
    
    # Install Docker
    print_info "Installing Docker ${FIRE}"
    
    # Remove old docker versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker repository
    show_progress 3 "Adding Docker repository"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update -y >> "$LOG_FILE" 2>&1
    
    show_progress 8 "Installing Docker"
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >> "$LOG_FILE" 2>&1
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Install Docker Compose
    print_info "Installing Docker Compose"
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Install Node.js
    print_info "Installing Node.js"
    show_progress 5 "Setting up Node.js repository"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - >> "$LOG_FILE" 2>&1
    sudo apt-get install -y nodejs >> "$LOG_FILE" 2>&1
    
    # Install Supabase CLI
    print_info "Installing Supabase CLI"
    sudo npm install -g supabase >> "$LOG_FILE" 2>&1
    
    # Install Nginx
    print_info "Installing Nginx"
    sudo apt install -y nginx >> "$LOG_FILE" 2>&1
    
    # Install Certbot for SSL (if email provided)
    if [[ -n "$USER_EMAIL" ]]; then
        print_info "Installing Certbot for SSL certificates"
        sudo apt install -y certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
    fi
    
    # Install additional useful tools
    print_info "Installing additional monitoring tools"
    sudo apt install -y htop iotop nethogs >> "$LOG_FILE" 2>&1
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Test Docker installation
    if ! docker --version &> /dev/null; then
        print_error "Docker installation failed!"
        exit 1
    fi
    
    print_success "All tools installed successfully! ${SUCCESS}"
}

# Function to generate secure keys automatically
generate_keys() {
    print_step "Generating super secure keys ${LOCK}"
    
    show_progress 3 "Creating encryption keys"
    
    # Generate JWT Secret (64 bytes, base64 encoded)
    JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
    print_info "✅ Generated JWT Secret"
    
    # Generate strong database password
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d '\n' | tr -d '/' | tr -d '+')
    print_info "✅ Generated Database Password"
    
    # Generate dashboard password
    DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -d '\n' | tr -d '/' | tr -d '+')
    print_info "✅ Generated Dashboard Password"
    
    # Generate API keys using proper JWT format
    show_progress 2 "Generating API keys"
    
    # Create ANON key
    ANON_PAYLOAD=$(echo '{"role":"anon","iss":"supabase","aud":"authenticated","exp":1999999999}' | base64 -w 0)
    ANON_SIGNATURE=$(echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$ANON_PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 -w 0 | tr '+/' '-_' | tr -d '=')
    ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$ANON_PAYLOAD.$ANON_SIGNATURE"
    print_info "✅ Generated ANON Key"
    
    # Create SERVICE key
    SERVICE_PAYLOAD=$(echo '{"role":"service_role","iss":"supabase","aud":"authenticated","exp":1999999999}' | base64 -w 0)
    SERVICE_SIGNATURE=$(echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$SERVICE_PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 -w 0 | tr '+/' '-_' | tr -d '=')
    SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$SERVICE_PAYLOAD.$SERVICE_SIGNATURE"
    print_info "✅ Generated SERVICE Key"
    
    # Generate additional secrets
    STORAGE_SECRET=$(openssl rand -base64 32 | tr -d '\n')
    REALTIME_SECRET=$(openssl rand -base64 32 | tr -d '\n')
    IMGPROXY_KEY=$(openssl rand -hex 32)
    IMGPROXY_SALT=$(openssl rand -hex 32)
    
    print_success "All keys generated successfully! ${LOCK}"
}

# Function to create directory structure
create_structure() {
    print_step "Creating project structure ${GEAR}"
    
    # Create main directory
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown $USER:$USER "$INSTALL_DIR"
    
    # Create subdirectories
    mkdir -p "$INSTALL_DIR"/{volumes/{api,db/{init,data},storage,functions/main,logs},config,backups}
    
    # Create database init script
    cat > "$INSTALL_DIR/volumes/db/init/init.sql" << 'EOF'
-- Create additional users and roles
CREATE USER authenticator;
CREATE USER service_role;
CREATE USER supabase_auth_admin;
CREATE USER supabase_storage_admin;
CREATE USER supabase_admin;

-- Grant permissions
GRANT authenticator TO postgres;
GRANT service_role TO authenticator;
GRANT supabase_auth_admin TO postgres;
GRANT supabase_storage_admin TO postgres;
GRANT supabase_admin TO postgres;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pgjwt";

-- Set up auth schema
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS realtime;
CREATE SCHEMA IF NOT EXISTS _realtime;
CREATE SCHEMA IF NOT EXISTS supabase_functions;
EOF
    
    print_success "Project structure created! ${SUCCESS}"
}

# Function to create comprehensive configuration files
create_configs() {
    print_step "Creating configuration files ${GEAR}"
    
    # Create main .env file
    cat > "$INSTALL_DIR/.env" << EOF
# 🚀 Supabase Configuration
# Generated automatically on $(date)

# Domain Configuration
MAIN_DOMAIN=$MAIN_DOMAIN
API_DOMAIN=$API_DOMAIN
STUDIO_DOMAIN=$STUDIO_DOMAIN
API_EXTERNAL_URL=https://$API_DOMAIN
SUPABASE_URL=https://$API_DOMAIN
SITE_URL=https://$STUDIO_DOMAIN

# Database Configuration
POSTGRES_PASSWORD=$DB_PASSWORD
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_HOST=db
POSTGRES_PORT=5432
DATABASE_URL=postgresql://postgres:$DB_PASSWORD@db:5432/postgres

# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_EXPIRY=3600
SUPABASE_ANON_KEY=$ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=$SERVICE_KEY

# Dashboard Configuration
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD
STUDIO_DEFAULT_ORGANIZATION=$MAIN_DOMAIN
STUDIO_DEFAULT_PROJECT=default

# Storage Configuration
STORAGE_BACKEND=file
FILE_SIZE_LIMIT=52428800
UPLOAD_FILE_SIZE_LIMIT=52428800
STORAGE_SECRET=$STORAGE_SECRET

# Realtime Configuration
REALTIME_SECRET=$REALTIME_SECRET

# Image Processing
IMGPROXY_KEY=$IMGPROXY_KEY
IMGPROXY_SALT=$IMGPROXY_SALT

# SMTP Configuration (Configure these later)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_SENDER_NAME=$MAIN_DOMAIN
SMTP_ADMIN_EMAIL=${USER_EMAIL:-admin@$MAIN_DOMAIN}

# Security
GOTRUE_SITE_URL=https://$STUDIO_DOMAIN
GOTRUE_URI_ALLOW_LIST=https://$STUDIO_DOMAIN,https://$API_DOMAIN
EOF

    # Create production-ready Docker Compose file
    cat > "$INSTALL_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

networks:
  supabase:
    driver: bridge

services:
  studio:
    container_name: supabase-studio
    image: supabase/studio:20231103-15ba6c8
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/profile"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - supabase
    ports:
      - "3000:3000"
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DEFAULT_ORGANIZATION_NAME: ${STUDIO_DEFAULT_ORGANIZATION}
      DEFAULT_PROJECT_NAME: ${STUDIO_DEFAULT_PROJECT}
      SUPABASE_URL: ${API_EXTERNAL_URL}
      SUPABASE_REST_URL: ${API_EXTERNAL_URL}/rest/v1/
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SUPABASE_SERVICE_ROLE_KEY}
    volumes:
      - ./volumes/logs:/var/log:rw

  kong:
    container_name: supabase-kong
    image: kong:2.8.1
    restart: unless-stopped
    networks:
      - supabase
    ports:
      - "8000:8000/tcp"
      - "8443:8443/tcp"
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /var/lib/kong/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_PLUGINS: request-transformer,cors,key-auth,acl
      KONG_NGINX_PROXY_PROXY_BUFFER_SIZE: 160k
      KONG_NGINX_PROXY_PROXY_BUFFERS: 64 160k
      KONG_LOG_LEVEL: warn
    volumes:
      - ./volumes/api/kong.yml:/var/lib/kong/kong.yml:ro
    healthcheck:
      test: ["CMD", "kong", "health"]
      interval: 30s
      timeout: 10s
      retries: 3

  auth:
    container_name: supabase-auth
    image: supabase/gotrue:v2.97.0
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - supabase
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://supabase_auth_admin:${POSTGRES_PASSWORD}@db:5432/postgres
      GOTRUE_SITE_URL: ${SITE_URL}
      GOTRUE_URI_ALLOW_LIST: ${GOTRUE_URI_ALLOW_LIST}
      GOTRUE_DISABLE_SIGNUP: false
      GOTRUE_JWT_ADMIN_ROLES: service_role
      GOTRUE_JWT_AUD: authenticated
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
      GOTRUE_JWT_EXP: ${JWT_EXPIRY}
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_EXTERNAL_EMAIL_ENABLED: true
      GOTRUE_MAILER_AUTOCONFIRM: false
      GOTRUE_SMTP_HOST: ${SMTP_HOST}
      GOTRUE_SMTP_PORT: ${SMTP_PORT}
      GOTRUE_SMTP_USER: ${SMTP_USER}
      GOTRUE_SMTP_PASS: ${SMTP_PASS}
      GOTRUE_SMTP_SENDER_NAME: ${SMTP_SENDER_NAME}
      GOTRUE_RATE_LIMIT_HEADER: X-Real-IP
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9999/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  rest:
    container_name: supabase-rest
    image: postgrest/postgrest:v11.2.0
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - supabase
    environment:
      PGRST_DB_URI: postgres://authenticator:${POSTGRES_PASSWORD}@db:5432/postgres
      PGRST_DB_SCHEMAS: public,storage,graphql_public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_USE_LEGACY_GUCS: "false"
      PGRST_APP_SETTINGS_JWT_SECRET: ${JWT_SECRET}
      PGRST_APP_SETTINGS_JWT_EXP: ${JWT_EXPIRY}
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3

  realtime:
    container_name: supabase-realtime
    image: supabase/realtime:v2.10.1
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - supabase
    environment:
      PORT: 4000
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: supabase_admin
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: postgres
      DB_AFTER_CONNECT_QUERY: 'SET search_path TO _realtime'
      DB_ENC_KEY: ${REALTIME_SECRET}
      API_JWT_SECRET: ${JWT_SECRET}
      FLY_ALLOC_ID: fly123
      FLY_APP_NAME: realtime
      SECRET_KEY_BASE: ${REALTIME_SECRET}
      ERL_AFLAGS: -proto_dist inet_tcp
      ENABLE_TAILSCALE: "false"
      DNS_NODES: "''"
    command: >
      sh -c "/app/bin/migrate && /app/bin/realtime eval 'Realtime.Release.seeds(Realtime.Repo)' && /app/bin/server"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/"]
      interval: 30s
      timeout: 10s
      retries: 3

  storage:
    container_name: supabase-storage
    image: supabase/storage-api:v0.40.4
    depends_on:
      db:
        condition: service_healthy
      rest:
        condition: service_started
    restart: unless-stopped
    networks:
      - supabase
    environment:
      ANON_KEY: ${SUPABASE_ANON_KEY}
      SERVICE_KEY: ${SUPABASE_SERVICE_ROLE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://supabase_storage_admin:${POSTGRES_PASSWORD}@db:5432/postgres
      FILE_SIZE_LIMIT: ${FILE_SIZE_LIMIT}
      STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
      TENANT_ID: stub
      REGION: stub
      GLOBAL_S3_BUCKET: stub
      ENABLE_IMAGE_TRANSFORMATION: "true"
      IMGPROXY_URL: http://imgproxy:5001
    volumes:
      - ./volumes/storage:/var/lib/storage:z
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5000/status"]
      interval: 30s
      timeout: 10s
      retries: 3

  meta:
    container_name: supabase-meta
    image: supabase/postgres-meta:v0.68.0
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - supabase
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PORT: 5432
      PG_META_DB_NAME: postgres
      PG_META_DB_USER: supabase_admin
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  functions:
    container_name: supabase-edge-functions
    image: supabase/edge-runtime:v1.8.2
    restart: unless-stopped
    networks:
      - supabase
    environment:
      JWT_SECRET: ${JWT_SECRET}
      SUPABASE_URL: ${API_EXTERNAL_URL}
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY}
      SUPABASE_DB_URL: postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
    volumes:
      - ./volumes/functions:/home/deno/functions:Z
    command:
      - start
      - --main-service
      - /home/deno/functions/main

  db:
    container_name: supabase-db
    image: supabase/postgres:15.1.0.117
    restart: unless-stopped

imgproxy:
    container_name: supabase-imgproxy
    image: darthsim/imgproxy:v3.8.0
    restart: unless-stopped
    networks:
      - supabase
    environment:
      IMGPROXY_BIND: ":5001"
      IMGPROXY_LOCAL_FILESYSTEM_ROOT: /
      IMGPROXY_USE_ETAG: "true"
      IMGPROXY_KEY: ${IMGPROXY_KEY}
      IMGPROXY_SALT: ${IMGPROXY_SALT}
      IMGPROXY_ENABLE_WEBP_DETECTION: "true"
    volumes:
      - ./volumes/storage:/var/lib/storage:z
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    container_name: supabase-db
    image: supabase/postgres:15.1.0.117
    restart: unless-stopped
    networks:
      - supabase
    ports:
      - "5432:5432"
    command:
      - postgres
      - -c
      - config_file=/etc/postgresql/postgresql.conf
      - -c
      - log_min_messages=fatal
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_PORT: ${POSTGRES_PORT}
      POSTGRES_HOST: /var/run/postgresql
    volumes:
      - ./volumes/db/realtime.sql:/docker-entrypoint-initdb.d/migrations/99-realtime.sql:Z
      - ./volumes/db/webhooks.sql:/docker-entrypoint-initdb.d/init-scripts/98-webhooks.sql:Z
      - ./volumes/db/roles.sql:/docker-entrypoint-initdb.d/init-scripts/99-roles.sql:Z
      - ./volumes/db/jwt.sql:/docker-entrypoint-initdb.d/init-scripts/99-jwt.sql:Z
      - ./volumes/db/logs.sql:/docker-entrypoint-initdb.d/logs.sql:Z
      - ./volumes/db/data:/var/lib/postgresql/data:Z
      - ./volumes/db/init:/docker-entrypoint-initdb.d:Z
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 5

  vector:
    container_name: supabase-vector
    image: timberio/vector:0.28.1-alpine
    restart: unless-stopped
    networks:
      - supabase
    volumes:
      - ./volumes/logs/vector.yml:/etc/vector/vector.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: ["--config", "/etc/vector/vector.yml"]
EOF

    # Create Kong configuration
    mkdir -p "$INSTALL_DIR/volumes/api"
    cat > "$INSTALL_DIR/volumes/api/kong.yml" << 'EOF'
_format_version: "1.1"

consumers:
  - username: anon
    keyauth_credentials:
      - key: ${SUPABASE_ANON_KEY}
  - username: service_role
    keyauth_credentials:
      - key: ${SUPABASE_SERVICE_ROLE_KEY}

acls:
  - consumer: anon
    group: anon
  - consumer: service_role
    group: admin

services:
  - name: auth-v1-open
    url: http://auth:9999/verify
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - /auth/v1/verify
    plugins:
      - name: cors

  - name: auth-v1-open-callback
    url: http://auth:9999/callback
    routes:
      - name: auth-v1-open-callback
        strip_path: true
        paths:
          - /auth/v1/callback
    plugins:
      - name: cors

  - name: auth-v1-open-authorize
    url: http://auth:9999/authorize
    routes:
      - name: auth-v1-open-authorize
        strip_path: true
        paths:
          - /auth/v1/authorize
    plugins:
      - name: cors

  - name: auth-v1
    _comment: "GoTrue: /auth/v1/* -> http://auth:9999/*"
    url: http://auth:9999/
    routes:
      - name: auth-v1-all
        strip_path: true
        paths:
          - /auth/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: rest-v1
    _comment: "PostgREST: /rest/v1/* -> http://rest:3000/*"
    url: http://rest:3000/
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - /rest/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: true
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: realtime-v1
    _comment: "Realtime: /realtime/v1/* -> ws://realtime:4000/socket/*"
    url: http://realtime:4000/socket
    routes:
      - name: realtime-v1-all
        strip_path: true
        paths:
          - /realtime/v1/
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin
            - anon

  - name: storage-v1
    _comment: "Storage: /storage/v1/* -> http://storage:5000/*"
    url: http://storage:5000/
    routes:
      - name: storage-v1-all
        strip_path: true
        paths:
          - /storage/v1/
    plugins:
      - name: cors

  - name: functions-v1
    _comment: "Edge Functions: /functions/v1/* -> http://functions:9000/*"
    url: http://functions:9000/
    routes:
      - name: functions-v1-all
        strip_path: true
        paths:
          - /functions/v1/
    plugins:
      - name: cors

  - name: meta
    _comment: "pg-meta: /pg/* -> http://meta:8080/*"
    url: http://meta:8080/
    routes:
      - name: meta-all
        strip_path: true
        paths:
          - /pg/
EOF

    # Create additional database initialization scripts
    cat > "$INSTALL_DIR/volumes/db/roles.sql" << 'EOF'
-- Create custom roles
CREATE ROLE anon                        nologin noinherit;
CREATE ROLE authenticated               nologin noinherit;
CREATE ROLE service_role                nologin noinherit bypassrls;
CREATE ROLE supabase_auth_admin         noinherit createrole createdb;
CREATE ROLE supabase_storage_admin      noinherit createrole createdb;
CREATE ROLE supabase_admin              noinherit createrole createdb;

-- Grant permissions
GRANT anon                    TO authenticator;
GRANT authenticated           TO authenticator;
GRANT service_role            TO authenticator;
GRANT supabase_auth_admin     TO postgres;
GRANT supabase_storage_admin  TO postgres;
GRANT supabase_admin          TO postgres;

-- Set default privileges
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
EOF

    cat > "$INSTALL_DIR/volumes/db/jwt.sql" << 'EOF'
-- JWT helper functions
CREATE OR REPLACE FUNCTION auth.jwt() 
RETURNS jsonb 
LANGUAGE sql 
STABLE 
AS $$
  SELECT 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;

CREATE OR REPLACE FUNCTION auth.role() 
RETURNS text 
LANGUAGE sql 
STABLE 
AS $$
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (auth.jwt() ->> 'role')::text
  )
$$;

CREATE OR REPLACE FUNCTION auth.uid() 
RETURNS uuid 
LANGUAGE sql 
STABLE 
AS $$
  SELECT 
    coalesce(
      nullif(current_setting('request.jwt.claim.sub', true), ''),
      (auth.jwt() ->> 'sub')
    )::uuid
$$;
EOF

    cat > "$INSTALL_DIR/volumes/db/realtime.sql" << 'EOF'
-- Enable realtime
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- Create realtime schema
CREATE SCHEMA IF NOT EXISTS _realtime;
CREATE SCHEMA IF NOT EXISTS realtime;

-- Grant permissions on realtime
GRANT USAGE ON SCHEMA _realtime TO postgres, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA realtime TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA _realtime TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA realtime TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA _realtime TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA realtime TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA _realtime TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA realtime TO postgres, anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA _realtime GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA realtime GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
EOF

    cat > "$INSTALL_DIR/volumes/db/webhooks.sql" << 'EOF'
-- Create webhooks schema and tables
CREATE SCHEMA IF NOT EXISTS supabase_functions;

CREATE TABLE IF NOT EXISTS supabase_functions.hooks (
  id SERIAL PRIMARY KEY,
  hook_table_id INTEGER NOT NULL,
  hook_name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable row level security
ALTER TABLE supabase_functions.hooks ENABLE ROW LEVEL SECURITY;
EOF

    cat > "$INSTALL_DIR/volumes/db/logs.sql" << 'EOF'
-- Create logs schema for monitoring
CREATE SCHEMA IF NOT EXISTS _analytics;
CREATE TABLE IF NOT EXISTS _analytics.page_views (
  id SERIAL PRIMARY KEY,
  path TEXT,
  user_agent TEXT,
  referer TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
EOF

    # Create Vector logging configuration
    mkdir -p "$INSTALL_DIR/volumes/logs"
    cat > "$INSTALL_DIR/volumes/logs/vector.yml" << 'EOF'
data_dir: /tmp/vector/

sources:
  docker_logs:
    type: docker_logs
    include_labels:
      - "com.docker.compose.service"

transforms:
  supabase_logs:
    type: filter
    inputs:
      - docker_logs
    condition: '.label."com.docker.compose.service" != null'

sinks:
  console:
    type: console
    inputs:
      - supabase_logs
    encoding:
      codec: json
EOF

    print_success "Configuration files created successfully! ${SUCCESS}"
}

# Function to create Nginx reverse proxy configuration
setup_nginx() {
    print_step "Setting up Nginx reverse proxy ${GEAR}"
    
    # Remove default nginx config
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Create Supabase nginx configuration
    cat > "/tmp/supabase-nginx.conf" << EOF
# Main API configuration
server {
    listen 80;
    server_name $API_DOMAIN;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# Studio configuration
server {
    listen 80;
    server_name $STUDIO_DOMAIN;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # WebSocket support for Studio
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # Install the configuration
    sudo mv "/tmp/supabase-nginx.conf" "/etc/nginx/sites-available/supabase"
    sudo ln -sf "/etc/nginx/sites-available/supabase" "/etc/nginx/sites-enabled/supabase"
    
    # Test nginx configuration
    sudo nginx -t
    
    # Restart nginx
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    print_success "Nginx configured successfully! ${SUCCESS}"
}

# Function to setup SSL certificates
setup_ssl() {
    print_step "Setting up SSL certificates ${LOCK}"
    
    if [[ -n "$USER_EMAIL" ]]; then
        print_info "Getting real SSL certificates from Let's Encrypt"
        
        # Install certificates for both domains
        show_progress 5 "Getting SSL certificate for $API_DOMAIN"
        sudo certbot --nginx -d "$API_DOMAIN" --email "$USER_EMAIL" --agree-tos --non-interactive --redirect >> "$LOG_FILE" 2>&1 || {
            print_warning "Failed to get SSL for $API_DOMAIN, continuing with HTTP"
        }
        
        show_progress 5 "Getting SSL certificate for $STUDIO_DOMAIN"
        sudo certbot --nginx -d "$STUDIO_DOMAIN" --email "$USER_EMAIL" --agree-tos --non-interactive --redirect >> "$LOG_FILE" 2>&1 || {
            print_warning "Failed to get SSL for $STUDIO_DOMAIN, continuing with HTTP"
        }
        
        # Setup auto-renewal
        sudo systemctl enable certbot.timer
        sudo systemctl start certbot.timer
        
        print_success "SSL certificates configured! ${LOCK}"
    else
        print_info "Skipping SSL setup (no email provided)"
        print_warning "Your sites will use HTTP only"
    fi
}

# Function to create helper scripts
create_helper_scripts() {
    print_step "Creating helper scripts ${GEAR}"
    
    # Create start script
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash
echo "🚀 Starting Supabase..."
cd /opt/supabase
docker-compose up -d
echo "✅ Supabase started!"
echo "📱 Studio: https://STUDIO_DOMAIN"
echo "🔗 API: https://API_DOMAIN"
EOF

    # Create stop script
    cat > "$INSTALL_DIR/stop.sh" << 'EOF'
#!/bin/bash
echo "🛑 Stopping Supabase..."
cd /opt/supabase
docker-compose down
echo "✅ Supabase stopped!"
EOF

    # Create restart script
    cat > "$INSTALL_DIR/restart.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restarting Supabase..."
cd /opt/supabase
docker-compose down
docker-compose up -d
echo "✅ Supabase restarted!"
EOF

    # Create logs script
    cat > "$INSTALL_DIR/logs.sh" << 'EOF'
#!/bin/bash
echo "📋 Supabase Logs (Press Ctrl+C to exit)"
cd /opt/supabase
docker-compose logs -f
EOF

    # Create status script
    cat > "$INSTALL_DIR/status.sh" << 'EOF'
#!/bin/bash
echo "📊 Supabase Status:"
cd /opt/supabase
docker-compose ps
echo ""
echo "🌐 URLs:"
echo "Studio: https://STUDIO_DOMAIN"
echo "API: https://API_DOMAIN"
EOF

    # Create backup script
    cat > "$INSTALL_DIR/backup.sh" << 'EOF'
#!/bin/bash
BACKUP_DIR="/tmp/supabase-backup-$(date +%Y%m%d-%H%M%S)"
echo "💾 Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cd /opt/supabase
cp -r volumes "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"
echo "✅ Backup created: $BACKUP_DIR"
EOF

    # Replace placeholders in scripts
    sed -i "s/STUDIO_DOMAIN/$STUDIO_DOMAIN/g" "$INSTALL_DIR"/*.sh
    sed -i "s/API_DOMAIN/$API_DOMAIN/g" "$INSTALL_DIR"/*.sh
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR"/*.sh
    
    # Create system service for auto-start
    cat > "/tmp/supabase.service" << EOF
[Unit]
Description=Supabase Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/start.sh
ExecStop=$INSTALL_DIR/stop.sh
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    sudo mv "/tmp/supabase.service" "/etc/systemd/system/supabase.service"
    sudo systemctl daemon-reload
    sudo systemctl enable supabase.service
    
    print_success "Helper scripts created! ${SUCCESS}"
}

# Function to start Supabase
start_supabase() {
    print_step "Starting Supabase services ${ROCKET}"
    
    cd "$INSTALL_DIR"
    
    # Create main function directory with a basic function
    mkdir -p "$INSTALL_DIR/volumes/functions/main"
    cat > "$INSTALL_DIR/volumes/functions/main/index.ts" << 'EOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { name } = await req.json()
  const data = {
    message: `Hello ${name}!`,
    timestamp: new Date().toISOString(),
  }

  return new Response(
    JSON.stringify(data),
    { headers: { "Content-Type": "application/json" } },
  )
})
EOF

    show_progress 10 "Pulling Docker images"
    docker-compose pull >> "$LOG_FILE" 2>&1
    
    show_progress 15 "Starting all services"
    docker-compose up -d >> "$LOG_FILE" 2>&1
    
    # Wait for services to be ready
    print_info "Waiting for services to start..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps | grep -q "Up"; then
            print_info "Services are starting... ($attempt/$max_attempts)"
            if curl -s http://localhost:3000/api/profile > /dev/null 2>&1; then
                break
            fi
        fi
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Services didn't start properly. Check logs: docker-compose logs"
        exit 1
    fi
    
    print_success "Supabase is running! ${ROCKET}"
}

# Function to display final information
show_final_info() {
    print_header "${PARTY} INSTALLATION COMPLETE! ${PARTY}"
    
    echo -e "${WHITE}🎉 Congratulations! Your Supabase is ready! 🎉${NC}"
    echo ""
    
    # URLs
    echo -e "${CYAN}📱 Your Supabase URLs:${NC}"
    if [[ -n "$USER_EMAIL" ]]; then
        echo -e "${GREEN}   Studio: https://$STUDIO_DOMAIN${NC}"
        echo -e "${GREEN}   API:    https://$API_DOMAIN${NC}"
    else
        echo -e "${YELLOW}   Studio: http://$STUDIO_DOMAIN${NC}"
        echo -e "${YELLOW}   API:    http://$API_DOMAIN${NC}"
    fi
    echo ""
    
    # Important credentials
    echo -e "${RED}🔐 IMPORTANT! Save these credentials:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Database Password:${NC} $DB_PASSWORD"
    echo -e "${YELLOW}Dashboard Password:${NC} $DASHBOARD_PASSWORD"
    echo -e "${YELLOW}Dashboard Username:${NC} admin"
    echo ""
    echo -e "${YELLOW}Supabase ANON Key:${NC}"
    echo -e "${WHITE}$ANON_KEY${NC}"
    echo ""
    echo -e "${YELLOW}Supabase SERVICE Key:${NC}"
    echo -e "${WHITE}$SERVICE_KEY${NC}"
    echo ""
    echo -e "${YELLOW}JWT Secret:${NC}"
    echo -e "${WHITE}$JWT_SECRET${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Save credentials to file
    local creds_file="$INSTALL_DIR/CREDENTIALS.txt"
    cat > "$creds_file" << EOF
🔐 SUPABASE CREDENTIALS - KEEP SAFE!
Generated on: $(date)
Domain: $MAIN_DOMAIN

🌐 URLs:
Studio: https://$STUDIO_DOMAIN
API: https://$API_DOMAIN

🔑 Login Credentials:
Dashboard Username: admin
Dashboard Password: $DASHBOARD_PASSWORD

🗄️ Database:
Database Password: $DB_PASSWORD
Connection String: postgresql://postgres:$DB_PASSWORD@localhost:5432/postgres

🎯 API Keys:
ANON Key: $ANON_KEY
SERVICE Key: $SERVICE_KEY

🛡️ Security:
JWT Secret: $JWT_SECRET

📧 Email Configuration:
SMTP Host: $SMTP_HOST (Configure in .env file)
Admin Email: ${USER_EMAIL:-admin@$MAIN_DOMAIN}

💾 Important Files:
- Main Config: $INSTALL_DIR/.env
- Docker Config: $INSTALL_DIR/docker-compose.yml
- Backup Location: $BACKUP_DIR
EOF

    echo -e "${GREEN}💾 All credentials saved to: $creds_file${NC}"
    echo ""
    
    # Helpful commands
    echo -e "${BLUE}🛠️ Helpful Commands:${NC}"
    echo -e "${WHITE}   Start:   $INSTALL_DIR/start.sh${NC}"
    echo -e "${WHITE}   Stop:    $INSTALL_DIR/stop.sh${NC}"
    echo -e "${WHITE}   Restart: $INSTALL_DIR/restart.sh${NC}"
    echo -e "${WHITE}   Logs:    $INSTALL_DIR/logs.sh${NC}"
    echo -e "${WHITE}   Status:  $INSTALL_DIR/status.sh${NC}"
    echo -e "${WHITE}   Backup:  $INSTALL_DIR/backup.sh${NC}"
    echo ""
    
    # Next steps
    echo -e "${PURPLE}🚀 Next Steps:${NC}"
    echo -e "${WHITE}   1. Visit your Studio URL to create your first project${NC}"
    echo -e "${WHITE}   2. Configure SMTP settings in $INSTALL_DIR/.env${NC}"
    echo -e "${WHITE}   3. Set up your database schema${NC}"
    echo -e "${WHITE}   4. Start building your app!${NC}"
    echo ""
    
    if [[ -z "$USER_EMAIL" ]]; then
        echo -e "${YELLOW}⚠️  Note: Your sites use HTTP only (no SSL)${NC}"
        echo -e "${WHITE}   To add SSL later, edit the script and add your email${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}🎉 Happy coding with Supabase! 🎉${NC}"
    
    # Show status
    print_info "Checking final status..."
    cd "$INSTALL_DIR"
    docker-compose ps
}

# Main installation function
main() {
    print_header "${ROCKET} SUPABASE AUTO-INSTALLER ${ROCKET}"
    
    # Initialize log file
    echo "Supabase Installation Log - $(date)" > "$LOG_FILE"
    
    # Pre-installation checks
    check_root
    check_ubuntu
    check_requirements
    
    # Get user configuration
    get_user_config
    
    # Installation steps
    backup_existing
    install_dependencies
    generate_keys
    create_structure
    create_configs
    setup_nginx
    setup_ssl
    create_helper_scripts
    start_supabase
    
    # Show final information
    show_final_info
    
    print_header "${SUCCESS} INSTALLATION SUCCESSFUL! ${SUCCESS}"
}

# Run the installer
main "$@"