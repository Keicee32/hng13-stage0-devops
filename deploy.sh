#!/bin/bash

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

#get DIR out of repo name
REPO_DIR=$(basename "$GITHUB_URL" .git) #Basename removes the lines https://github.com/ and leaves name of the repo while the .git removes the .git extension.



# Connect using the valid input
echo ""
echo "Connection details confirmed."
echo "Attempting to connect to $USERNAME@$IP using key: $SSH_KEY_PATH"

# Assuming you have a retry function defined earlier in the script
# retry_command 5 10 ssh -i "$SSH_KEY_PATH" "$USERNAME@$IP"

# Or, without the retry function:
/usr/bin/ssh -i "$SSH_KEY_PATH" "$USERNAME@$IP" << 'EOF' 
	sudo apt update && sudo apt install git docker.io nginx docker-compose -y
	sudo usermod -aG docker ubuntu
	newgrp docker
	sudo systemctl enable docker && sudo systemctl start docker && sudo systemctl start nginx && sudo systemctl enable nginx
	docker --version && nginx --version & docker-compose --version
	mkdir HNG && cd HNG
	if [ ! -d $REPO_DIR ]; then
		git clone "https://${PAT}@${GITHUB_URL#http://}"
	else
		echo "${REPO_DIR} exists"
	fi
	cd $REPO_DIR
	if [ -f Dockerfile ] || [ -f docker-compose.yml ]
		echo "File is present"
	else
		echo "File not found"
	docker-compose up -d

EOF
