#!/bin/bash
### most Posix complaint prefer /sh as the endshebang lol research based learning begins
# Conditions should be set in the event of failures
set -e
set -o pipefail

# I need to understand the script fails and success, so i define my colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BLUE='\033[0;34m'
## these are the ANSI color codes for shell scripting (terminal use)s not HEX CODES.
## and these color codes style the text. This will help me understand errors

## I need to Log all my actions:
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
## i included the current timestamp, which is what i passed as the argument, and this is created in a file
## log messages will be displayed based on status of the automation
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# back to where we defined the colors(at the top), success means green
success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS" "$1"
}

# red means error
error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR" "$1"
    exit 1
}

# yellow means caution
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING" "$1"
}

# blue means info
info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log "INFO" "$1"
}

# this logged message is echoed on the terminal and at the same time logged but insight purposes
# for ease of debugging, we can implement error handling using trap class
trap 'error "Problem Occurred at line $LINENO. You need to locate ${LOG_FILE}."' ERR

## Hmmm do i do a banner
##########
#### this is how we collect user input
info "Firstly: We will be collecting deployment parameters..."
echo ""

## we need GIT Repo URL
read -p "Enter Git Repository URL: " REPO_URL
if [ -z "${REPO_URL}" ]; then
    error "URL cannot be empty bro!"
fi

# the -p tag is used to ask questions
## this is for PAT (Personal Access Token)
read -s -p "Enter Personal Access Token (PAT): " PAT
echo ""
if [ -z "${PAT}" ]; then
    error "Access Token is needed!"
fi

# Branch selection
read -p "Enter branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

# SSH Username
read -p "Enter server username (default: ubuntu): " USERNAME
USERNAME=${USERNAME:-ubuntu}

# Server IP Address
read -p "Enter server IP address: " SERVER_IP
if [ -z "${SERVER_IP}" ]; then
    error "Server IP is needed!"
fi

### Key Path to remote server
read -p "Enter SSH key path (default: ~/.ssh/hng-key.pem): " SSH_KEY
SSH_KEY=${SSH_KEY:-~/.ssh/hng-key.pem}
SSH_KEY="${SSH_KEY/#\~/$HOME}"
#### this ssh key resides on my local machine hidden always chmod 400 key path
if [ ! -f "${SSH_KEY}" ]; then
    error "SSH key not found at ${SSH_KEY}"
fi

# Application Port section
read -p "Enter application port (default: 3000): " APP_PORT
APP_PORT=${APP_PORT:-3000}

success "All Fields were correct!"
echo ""

# CLONE THE REPO
info "Secondly we will begin Cloning repository from GitHub..."
# Get repository name from URL
REPO_NAME=$(basename "${REPO_URL}" .git)
PROJECT_DIR="${REPO_NAME}"

# Check if directory already exists
if [ -d "${PROJECT_DIR}" ]; then
    warning "Directory ${PROJECT_DIR} already exists. Pulling latest changes..."
    cd "${PROJECT_DIR}"
    git pull origin "${BRANCH}" || error "Failed to pull latest changes"
    success "Pulled latest changes from ${BRANCH}"
else
    # Clone repository with PAT authentication code stored safely in my notes
    info "Cloning repository..."
    
    # Insert PAT into URL for authentication
    # Changes: https://github.com/user/repo.git
    # To: https://PAT@github.com/user/repo.git
    REPO_WITH_PAT=$(echo "${REPO_URL}" | sed "s|https://|https://${PAT}@|")
    
    git clone "${REPO_WITH_PAT}" || error "Failed to clone repository. Check URL and PAT."
    cd "${PROJECT_DIR}"
    success "Repository cloned successfully"
fi

# Switch to specified branch
info "Checking out branch: ${BRANCH}"
git checkout "${BRANCH}" || error "Failed to checkout branch ${BRANCH}"
success "Repository ready on branch: ${BRANCH}"
echo ""

#### THIRDLY WE WILL MAKE SURE THE APP STRUCTURE & FOUNDATIONS ARE GOOD
info "Thirdly, the application build..."
## check if Docker exist
if [ -f "Dockerfile" ]; then
    success "Found Dockerfile"
    DEPLOY_METHOD="dockerfile"
elif [ -f "docker-compose.yml" ]; then
    success "docker-compose.yml found"
    DEPLOY_METHOD="compose"
elif [ -f "docker-compose.yaml" ]; then
    success "docker-compose.yaml found"
    DEPLOY_METHOD="compose"
else
    error "No docker libraries and modules found! Cannot Proceed."
fi

# Let see the project content to be sure
info "Project contents:"
ls -la
echo

# TEST YOUR SSH CONNECTION
info "Testing connection..."
# Test basic connectivity with timeout with the append -o tag
if ssh -i "${SSH_KEY}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
    "${USERNAME}@${SERVER_IP}" "echo 'SSH connection successful'" 2>/dev/null; then
    success "SSH connection established successfully"
else
    error "Failed to connect to ${USERNAME}@${SERVER_IP}. Check:
    1. Server IP and SSH Key"
fi
echo ""

# SETUP REMOTE ENVIRONMENT
info "Setting up remote environment..."
ssh -i "${SSH_KEY}" "${USERNAME}@${SERVER_IP}" << 'ENDSSH'
    set -e
    
    echo "----------------------------------------"
    echo "Updating system packages..."
    echo "----------------------------------------"
    sudo apt-get update -y
    
    echo ""
    echo "----------------------------------------"
    echo "Installing Docker..."
    echo "----------------------------------------"
    
    # Check if Docker is already installed
    if ! command -v docker &> /dev/null; then
        echo "Docker not found."
        sudo apt-get install docker.io -y
        sudo systemctl start docker
        sudo systemctl enable docker
        echo "Docker installed"
    else
        echo "Docker already installed: $(docker --version)"
    fi
    
    echo ""
    echo "----------------------------------------"
    echo "Installing Docker Compose..."
    echo "----------------------------------------"
    
    # Check if Docker Compose is already installed
    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose not found. Installing..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo "Docker Compose installed successfully"
    else
        echo "Docker Compose already installed: $(docker-compose --version)"
    fi
    
    echo ""
    echo "----------------------------------------"
    echo "Installing Nginx..."
    echo "----------------------------------------"
    
    # Check if Nginx is already installed
    if ! command -v nginx &> /dev/null; then
        echo "Nginx not found. Installing..."
        sudo apt-get install nginx -y
        sudo systemctl start nginx
        sudo systemctl enable nginx
        echo "Nginx installed successfully"
    else
        echo "Nginx already installed: $(nginx -v 2>&1)"
    fi
    
    echo ""
    echo "----------------------------------------"
    echo "Configuring Docker permissions..."
    echo "----------------------------------------"
    
    # Add user to docker group
    sudo usermod -aG docker $USER || true
    
    echo ""
    echo "----------------------------------------"
    echo "Installation Summary:"
    echo "----------------------------------------"
    docker --version
    docker-compose --version
    nginx -v 2>&1
    echo "----------------------------------------"
    
ENDSSH

success "Remote environment was a GO"
echo ""

# DEPLOY THE APPLICATION
# Go back to parent directory (we're currently inside the repo)
cd ..

# Transfer project files to server
info "Transferring files to server..."
info "Source: ./${PROJECT_DIR}"
info "Destination: ${USERNAME}@${SERVER_IP}:~/deployment-app"

# I will be using both rsync and scp for this transfer
if command -v rsync &> /dev/null; then
    rsync -avz --progress -e "ssh -i ${SSH_KEY}" \
        "${PROJECT_DIR}/" "${USERNAME}@${SERVER_IP}:~/deployment-app/" || \
        error "Failed to transfer files via rsync"
else
    scp -i "${SSH_KEY}" -r "${PROJECT_DIR}" \
        "${USERNAME}@${SERVER_IP}:~/deployment-app" || \
        error "Failed to transfer files via scp"
fi

success "Files transferred successfully"

# Build and run Docker container on remote server
info "Building Docker...."
ssh -i "${SSH_KEY}" "${USERNAME}@${SERVER_IP}" << ENDSSH
    set -e
    cd ~/deployment-app
    
    echo "----------------------------------------"
    echo "Current directory contents:"
    ls -la
    echo "----------------------------------------"
    
    # Stop and remove old container if it exists
    if docker ps -a | grep -q my-app; then
        echo "Stopping existing container..."
        docker stop my-app 2>/dev/null || true
        docker rm my-app 2>/dev/null || true
        echo "Old container removed"
    fi
    
    # Remove old image file and rebuild
    if docker images | grep -q my-app; then
        echo "Removing old image..."
        docker rmi my-app 2>/dev/null || true
    fi
    
    echo ""
    echo "----------------------------------------"
    echo "Building Docker image..."
    echo "----------------------------------------"
    docker build -t my-app . || exit 1
    
    echo ""
    echo "----------------------------------------"
    echo "Starting container..."
    echo "----------------------------------------"
    docker run -d \
        --name my-app \
        -p ${APP_PORT}:${APP_PORT} \
        --restart unless-stopped \
        my-app || exit 1
    
    echo ""
    echo "Waiting for container to start..."
    sleep 5
    
    echo ""
    echo "----------------------------------------"
    echo "Container Status:"
    echo "----------------------------------------"
    
    if docker ps | grep -q my-app; then
        echo "✓ Container is running"
        docker ps | grep my-app
        echo ""
        echo "Container logs:"
        docker logs my-app --tail 20
    else
        echo "✗ Container failed to start!"
        echo "Container logs:"
        docker logs my-app || true
        exit 1
    fi
ENDSSH

success "Container running and deployed"
echo ""

# NGINX REVERSE PROXY SETUP
info "Setting up Nginx reverse proxy..."
ssh -i "${SSH_KEY}" "${USERNAME}@${SERVER_IP}" << ENDSSH
    set -e
    
    echo "Creating Nginx configuration..."
    
    # Create Nginx site configuration
    sudo tee /etc/nginx/sites-available/my-app > /dev/null <<'NGINX_CONFIG'
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINX_CONFIG
    
    echo "Enabling site..."
    # Enable the site by creating symbolic link
    sudo ln -sf /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/my-app
    
    # Remove default Nginx site
    sudo rm -f /etc/nginx/sites-enabled/default
    
    echo "Testing Nginx configuration..."
    sudo nginx -t || exit 1
    
    echo "Reloading Nginx..."
    sudo systemctl reload nginx
    
    echo "Nginx status:"
    sudo systemctl status nginx --no-pager | head -10
ENDSSH

success "Nginx setup ready"
echo ""

# CHECKING MY DEPLOYMENT
# Check Docker service
info "Checking Docker service..."
if ssh -i "${SSH_KEY}" "${USERNAME}@${SERVER_IP}" "sudo systemctl is-active docker" > /dev/null 2>&1; then
    success "Docker service is running"
else
    warning "Docker service may not be running properly"
fi

# Check container health
info "Checking container health..."
if ssh -i "${SSH_KEY}" "${USERNAME}@${SERVER_IP}" "docker ps | grep my-app" > /dev/null 2>&1; then
    success "Container 'my-app' is running"
    ssh -i "${SSH_KEY}" "${USERNAME}@${SERVER_IP}" "docker ps | grep my-app"
else
    error "Container is not running! Check logs with: ssh ${USERNAME}@${SERVER_IP} 'docker logs my-app'"
fi

# Check Nginx status
info "Checking Nginx service..."
if ssh -i "${SSH_KEY}" "${USERNAME}@${SERVER_IP}" "sudo systemctl is-active nginx" > /dev/null 2>&1; then
    success "Nginx service is running"
else
    warning "Nginx service may not be running properly"
fi

# Test application endpoint internally
info "Testing application endpoint internally..."
INTERNAL_TEST=$(ssh -i "${SSH_KEY}" "${USERNAME}@${SERVER_IP}" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT}" || echo "000")

if [ "${INTERNAL_TEST}" -ge 200 ] && [ "${INTERNAL_TEST}" -lt 400 ]; then
    success "Application responds internally (HTTP ${INTERNAL_TEST})"
else
    warning "Application may not be responding internally (HTTP ${INTERNAL_TEST})"
fi

# Test application endpoint externally
info "Testing application endpoint externally..."
sleep 3  # Give Nginx a moment to settle
EXTERNAL_TEST=$(curl -s -o /dev/null -w "%{http_code}" "http://${SERVER_IP}" 2>/dev/null || echo "000")

if [ "${EXTERNAL_TEST}" -ge 200 ] && [ "${EXTERNAL_TEST}" -lt 400 ]; then
    success "Application is accessible externally (HTTP ${EXTERNAL_TEST})"
else
    warning "Application may not be accessible externally (HTTP ${EXTERNAL_TEST})"
    info "This could be due to security group settings or firewall rules"
fi

echo ""
echo "═══════════════════════════════════════"
echo " DEPLOYMENT COMPLETE!"
echo "═══════════════════════════════════════"
echo ""
echo " Deployment Details:"
echo "  ├─ Repository: ${REPO_URL}"
echo "  ├─ Branch: ${BRANCH}"
echo "  ├─ Server: ${USERNAME}@${SERVER_IP}"
echo "  ├─ Application Port: ${APP_PORT}"
echo "  ├─ Container Name: my-app"
echo "  └─ Deploy Method: ${DEPLOY_METHOD}"
echo ""
echo " Access Your Application:"
echo "  → http://${SERVER_IP}"
echo ""
echo " Log File:"
echo "  → ${LOG_FILE}"
echo ""
echo "️ Useful Commands:"
echo "  • View logs: ssh -i ${SSH_KEY} ${USERNAME}@${SERVER_IP} 'docker logs my-app'"
echo "  • Stop app: ssh -i ${SSH_KEY} ${USERNAME}@${SERVER_IP} 'docker stop my-app'"
echo "  • Restart app: ssh -i ${SSH_KEY} ${USERNAME}@${SERVER_IP} 'docker restart my-app'"
echo "  • Cleanup: ./deploy.sh --cleanup"
echo ""
echo "════════════════════════════════════════"
echo ""

log "SUCCESS" "Deployment completed successfully at $(date)"
exit 0
