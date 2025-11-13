#!/usr/bin/env bash
set -e
sudo apt update -y
sudo apt install -y \
  build-essential gcc g++ cmake ninja-build pkg-config \
  git git-lfs tig pre-commit python3-dev python3-venv \
  python3-pip openjdk-17-jdk neovim vim nano micro \
  gdb lldb valgrind strace htop btop linux-tools-generic \
  curl wget rsync sqlite3 exa bat shellcheck dos2unix p7zip-full zip \
  language-pack-zh-hans language-pack-zh-hant ttf-wqy-zenhei ttf-wqy-microhei \
  linux-headers-$(uname -r) ipmitool* libnvidia-nscq-570 datacenter-gpu-manager \
  nvidia-driver-570 nvidia-fabricmanager-570 cuda-12-8 cuda-runtime-12-8 \
  cuda-toolkit-12-8 libnccl2=2.26.2-1+cuda12.8 libnccl-dev=2.26.2-1+cuda12.8\
  nvidia-utils-570 nvidia-dkms-570
  
fc-cache -fv

echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist-nouveau.conf
echo 'options nouveau modeset=0' >> /etc/modprobe.d/blacklist-nouveau.conf
update-initramfs -u
systemctl enable nvidia-dcgm
systemctl enable nvidia-fabricmanager
systemctl start nvidia-dcgm
eval "$(curl https://get.x-cmd.com)"

# nvm 
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
echo 'export CUDA_HOME=/usr/local/cuda'  >> ~/.bashrc


source ~/.bashrc
nvm install --lts
