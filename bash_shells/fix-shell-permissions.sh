#!/usr/bin/env bash
sudo chown -R root:root /etc/nixos/bash_shells
sudo chmod 755 /etc/nixos/bash_shells
sudo chmod 750 /etc/nixos/bash_shells/*.sh
sudo chmod 644 /etc/nixos/bash_shells/shell-index.txt

# makes root owner, executable for root, readable for non root-group