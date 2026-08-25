#!/usr/bin/env bash
# Host bootstrap for the media-server stack on Debian 13 "Trixie".
#
# Installs Docker Engine + Compose plugin and the NVIDIA Container Toolkit,
# then wires the NVIDIA runtime into Docker. Idempotent-ish: safe to re-run.
#
# Run with sudo:  sudo ./bootstrap.sh
# The user added to the docker group is $SUDO_USER (the human invoking sudo).
set -euo pipefail

DOCKER_USER="${SUDO_USER:-${USER}}"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root: sudo $0" >&2
    exit 1
  fi
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "[docker] already installed: $(docker --version)"
    return
  fi
  echo "[docker] adding official apt repo..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  local arch codename
  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
}

add_user_to_docker_group() {
  echo "[docker] adding '${DOCKER_USER}' to the docker group..."
  usermod -aG docker "${DOCKER_USER}"
  echo "[docker] NOTE: '${DOCKER_USER}' must start a new login shell for this to take effect."
}

install_nvidia_toolkit() {
  if command -v nvidia-ctk >/dev/null 2>&1; then
    echo "[nvidia] toolkit already installed: $(nvidia-ctk --version | head -1)"
  else
    echo "[nvidia] adding container-toolkit apt repo..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update
    apt-get install -y nvidia-container-toolkit
  fi
  echo "[nvidia] configuring Docker runtime..."
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker
}

main() {
  require_root
  install_docker
  add_user_to_docker_group
  install_nvidia_toolkit
  echo
  echo "Done. Verify GPU passthrough:"
  echo "  docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi"
  echo "Then, from this repo:  cp .env.example .env && docker compose up -d"
}

main "$@"
