#!/bin/bash

# Become root user
sudo su -

# Update software packages
sudo yum update -y

# Download AWS CLI package
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv.zip"

# Unzip file
unzip -q awscli.zip

# Install AWS CLI
./aws/install

# Check AWS CLI version
aws —version

# Download kubectl binary
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Give the binary executable permissions
sudo chmod +x ./kubectl

# Move binary to directory in system’s path
sudo mv kubectl /usr/local/bin/
export PATH=/usr/local/bin:$PATH 

# Check kubectl version
kubectl version -—client

# Installing kubectl bash completion on Linux
## If bash-completion is not installed on Linux, install the 'bash-completion' package
## via your distribution's package manager.
## Load the kubectl completion code for bash into the current shell
echo 'source <(kubectl completion bash)' >> ~/.bash_profile
## Write bash completion code to a file and source it from .bash_profile
# kubectl completion bash > ~/.kube/completion.bash.inc
# printf "
# # kubectl shell completion
# source '$HOME/.kube/completion.bash.inc'
# " >> $HOME/.bash_profile
# source $HOME/.bash_profile

# Set bash completion for kubectl alias (k)
echo 'alias k=kubectl' >> ~/.bashrc
# echo 'complete -F __start_kubectl k' >> ~/.bashrc

# Get platform
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

# Download eksctl tool for platform
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

# Extract binary
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

# Move binary to directory in system’s path
sudo mv /tmp/eksctl /usr/local/bin

# Check eksctl version
eksctl version

# Enable eksctl bash completion
. <(eksctl completion bash)
