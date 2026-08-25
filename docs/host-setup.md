# Host setup runbook (Debian 13 "Trixie")

The manual, human-readable version of what [`../bootstrap.sh`](../bootstrap.sh)
automates. Every command needs `sudo`. This captures the exact steps used to
stand up the original host, so a new machine can be reproduced faithfully.

## 1. Docker Engine + Compose plugin (official apt repo)

```bash
# Add Docker's signing key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repo (uses the running release's codename, e.g. trixie)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update

# Install
sudo apt-get install docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

Verify: `sudo docker run --rm hello-world` prints "Hello from Docker!".

## 2. Run docker without sudo

```bash
sudo usermod -aG docker "$USER"
```

Docker-group membership is **root-equivalent** — only grant it to a user that is
already trusted with sudo. Start a new login shell (or `newgrp docker`) for it to
take effect.

## 3. NVIDIA Container Toolkit

```bash
# Signing key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Repo
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update

# Install + wire into Docker
sudo apt-get install nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Requires a working host NVIDIA driver (`nvidia-smi` on the host first).

## 4. Verify GPU passthrough

```bash
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi
```

Should print the GPU table from *inside* a container. Once this works, the host
is ready — return to the [README](../README.md) to bring up the stack.
