#!/usr/bin/env bash
# =====================================================================
# Prepara una instancia EC2 con Ubuntu 24.04 para el chatbot:
# Docker, Docker Compose y 2 GB de memoria de intercambio.
#
# Uso (dentro de la instancia, en la carpeta del repositorio):
#   bash infrastructure/aws/instalar.sh
# =====================================================================
set -euo pipefail

echo "==> Paquetes base"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl git

echo "==> Docker desde el repositorio oficial"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

echo "==> Memoria de intercambio de 2 GB"
if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
fi

echo "==> Zona horaria de Bogotá"
sudo timedatectl set-timezone America/Bogota

docker --version
docker compose version
echo
echo "Listo. Sal de la sesión (exit) y vuelve a entrar por SSH para usar docker sin sudo."
