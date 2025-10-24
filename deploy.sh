#!/bin/bash

#Logging deployment script start
echo "=============================="=================
echo "🚀 Deployment Script Initiated 🚀"
echo "================================================"

LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'echo "❌ Error on line $LINENO. Exiting..."' ERR


# Acknowledge the user
echo "Please provide the server details for your SSH connection."
echo "======================================================="
echo ""

# Loop until a non-empty SSH key path is provided
SSH_KEY_PATH=""
while [ -z "$SSH_KEY_PATH" ]; do
    read -p "Please specify your SSH key path: " SSH_KEY_PATH
    if [ -z "$SSH_KEY_PATH" ]; then
        echo "Error: The SSH key path cannot be empty."
    fi
done

# Loop until a non-empty username is provided
USERNAME=""
while [ -z "$USERNAME" ]; do
    read -p "Please enter server username: " USERNAME
    if [ -z "$USERNAME" ]; then
        echo "Error: The username cannot be empty."
    fi
done

# Loop until a non-empty IP address is provided
IP=""
while [ -z "$IP" ]; do
    read -p "Please enter server IP: " IP
    if [ -z "$IP" ]; then
        echo "Error: The IP address cannot be empty."
    fi
done

# Validate that the key path exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Error: The specified key file does not exist. Please check the path."
    exit 1
fi

GITHUB_URL=""
while [ -z "$GITHUB_URL" ]; do
    read -p "Please enter github url: " GITHUB_URL
    if [ -z "$GITHUB_URL" ]; then
        echo "Error: The github url address cannot be empty."
    fi
done


PAT=""
while [ -z "$PAT" ]; do
    read -p "Please enter server Personal Access Token: " PAT
    if [ -z "$PAT" ]; then
        echo "Error: The Personal Access Token cannot be empty."
    fi
done


BRANCH=""
while [ -z "$BRANCH" ]; do
    read -p "Please enter server branch: " BRANCH
    if [ -z "$BRANCH" ]; then
        echo "Error: The branch cannot be empty."
    fi
done

APP_PORT=""
while [ -z "$APP_PORT" ]; do
    read -p "Please enter docker app internal port number: " APP_PORT
    if [ -z "$APP_PORT" ]; then
        echo "Error: The app port cannot be empty."
    fi
done


#get DIR out of repo name
REPO_DIR=$(basename "$GITHUB_URL" .git) #Basename removes the lines https://github.com/ and leaves name of the repo while the .git removes the .git extension.

DOCKER_COMPOSE_PROJECT_NAME="$REPO_DIR"_project


# Connect using the valid input
echo ""
echo "Connection details confirmed."
echo "Attempting to connect to $USERNAME@$IP using key: $SSH_KEY_PATH"


#SSH
nc -zv "$IP" 22

/usr/bin/ssh -i "$SSH_KEY_PATH" "$USERNAME@$IP" <<EOF 
	sudo apt update && sudo apt install git docker.io nginx docker-compose -y
	sudo usermod -aG docker ubuntu
	newgrp docker
	sudo systemctl enable docker && sudo systemctl start docker && sudo systemctl start nginx && sudo systemctl enable nginx
	systemctl status nginx && systemctl status docker
	docker --version && nginx --version & docker-compose --version
	mkdir HNG && cd HNG
	if [ ! -d $REPO_DIR ]; then
		git clone "https://${PAT}@${GITHUB_URL#http://}"
                cd $REPO_DIR
	else
		echo "🔄 Repository already exists. Pulling latest changes..."
 		cd $REPO_DIR
  		git fetch origin
  		git checkout "$BRANCH"
  		git pull origin "$BRANCH"

	fi
	cd $REPO_DIR

	if [ -f Dockerfile ]; then
		echo "File is present"
        sed -i "s/8000/$APP_PORT/g" backend/Dockerfile
        cat backend/Dockerfile | grep "EXPOSE"
    elif [ -f docker-compose.yml ]; then
        if docker ps -a --format '{{.Names}}' | grep -q "$DOCKER_COMPOSE_PROJECT_NAME"; then
            echo "Container already exists. Stopping and removing existing container..."
            docker-compose down -v
            docker-compose up -p "$DOCKER_COMPOSE_PROJECT_NAME" -d --build
        else
            docker-compose up -p "$DOCKER_COMPOSE_PROJECT_NAME" -d --build
        fi
    else
		echo "File not found"
    fi
    
    

EOF
