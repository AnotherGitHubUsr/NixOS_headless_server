# Headless Nixserver 

All of this is very much personal. It is tailored to my setup and what I want (not necessarily what I need). 
**<p align="center">YMMV</p>**

## Overview
- Modular, reproducible NixOS configuration.
- All secrets managed with agenix
- Kernel 6.12, ZFS 2.3.3, bcache, mergerfs, 
- Networking and monitoring.
- Docker and Incus both enabled, with bridges and storage drivers.

## Install Steps

1. **Prepare Secrets:**
   - For password: `openssl passwd -6`, save output, encrypt with `agenix -e`.
   - For tokens (GitHub, traefik, Cloudflare, letsencrypt): create plain files with just the token, encrypt each with agenix.
   - Place resulting `.age` files in `secrets/`.

2. **First Build:**
   - `~/.config/agenix/age.key` does not yet exist, so it is generated (if one does exist it will be used instead). **Backup immediately!**
   - If Password files do not exist they will be created as "missingpassword". **Change immediately! **

3. **Install:**
   - Boot NixOS
   - If you don't have git (fresh install / live iso) `nix-shell -p git` live
   - `sudo rm -rf /etc/nixos` 
        > *Note: NixOS only uses /etc/nixos at build. If you have a preexisting configuration/secrets/etc make sure to back them up beforehand*
   - `git clone https://github.com/AnotherGitHubUsr/NixOS_headless_server.git /etc/nixos`
   - `cd /etc/nixos`
   - run `nixos-install --flake .#nixserver`.

4. **GitHub Push:**
   - Upon successful build changes to `/etc/nixos` are pushed automagically to https://github.com/AnotherGitHubUser/NixOS_headless_server
   - Manual main release bumps, incremental minor releases. If another commit in the last 24h, it's considered a patch.

5. **Disk/Disko**
   - A storage map is created with documentation at `/etc/nixos/storage-map.txt`
   - Each disk is assigned a name of Discworld characters. 
   - Disko only formats disks that do not have a Discworld character name.
   - Bcache is used to cache a NAS
   - Write cache is flushed once every 24h or when write cache exceeds 100 GB

6. **Secrets in Containers:**
   - Mount any agenix-unlocked secret (e.g., Cloudflare API) into Docker/Incus using volumes or environment files.
   - See the docs for `docker-compose` or `incus` for injection best practices.

## Secret Rotation and Recovery

- **Password/Token Change:**  
  Regenerate file, re-encrypt with agenix, replace in `secrets/`, rebuild.
- **Lost age key:**  
  **Cannot recover secrets**. Restore from your backup of `~/.config/agenix/age.key`.
- **Leaked secret:**  
  Revoke, rotate, and replace ASAP.

## TrueNAS (in my setup)

- TrueNAS at `10.250.250.250` exposes 4 disks via iSCSI (mpio, persistent).
- Firewall only allows `/30` subnet comms between NAS and nixserver.
- iSCSI setup details, multipath, etc., see `disk.nix` and comments.
