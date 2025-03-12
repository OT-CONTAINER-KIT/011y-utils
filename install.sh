#!/bin/bash

set -e

# Update package list and install required dependencies
echo "Updating package list and installing prerequisites..."
sudo apt update && sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker’s official GPG key
echo "Adding Docker's official GPG key..."
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "Adding Docker repository..."
echo \  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
echo "Installing Docker..."
sudo apt update && sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Verify installation
echo "Verifying Docker installation..."
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Check Docker and Docker Compose version
docker --version
docker compose version

echo "Docker and Docker Compose installation completed successfully!"
echo "Please log out and log back in or restart your system to apply user group changes."

echo "Create dir"
mdkir -p /data/grafana/grafana-storage
mkdir grafana
