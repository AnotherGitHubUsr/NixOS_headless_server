---

# Headless Nixserver

All of this is very much personal. It is tailored to my setup and what I want (not necessarily what I need).  
<p align="center"><b>YMMV</b></p>
Version 2.0 will be called Almost Headless NickS

---

## Table of Contents

- [Overview](#overview)
- [Installation Steps](#installation-steps)
- [Secret Rotation and Recovery](#secret-rotation-and-recovery)
- [Disk/Disko/Discworld Labeling](#diskdisko-discworld-labeling)
- [Monitoring, Health, AV, Logging](#monitoring-health-av-logging)
- [NAS Integration](#nas-integration)
- [Repo Structure](#repo-structure)
- [References & Credits](#references--credits)

---

## Overview

- Reproducible NixOS configuration for a headless home server.
- All secrets managed with **agenix** and encrypted with age.
- Kernel 6.12, ZFS 2.3.3, bcachefs, mergerfs, Docker & Incus (LXD alt), AMD hardware flags.
- Full disk/partition automation and registry with **disko** and Discworld character labeling scheme.
- Monitoring smart/health, system logging, and AV—all logs persist on detritus.
- GitHub-based push (GitOps) with version bump logic. (In opposition to current affairs)
- All install/test automation scripts are in `/bash_shells/` and indexed.
- See `shell-index.txt` and `index.txt` for script and config indices.

---

## Installation Steps

1. **Prepare Secrets:**
   - For password: `openssl passwd -6`, save output, encrypt with `agenix -e`.
   - For tokens (GitHub, traefik, Cloudflare, letsencrypt): create plain files with just the token, encrypt each with agenix.
   - Place resulting `.age` files in `secrets/`.

2. **First Build:**
   - If `~/.config/agenix/age.key` does not exist, it is generated (if one does exist it will be used instead). **Backup immediately!**
   - If Password files do not exist they will be created as "missingpassword". **Change immediately!**

3. **Install:**
   - Boot NixOS (live, clean, dirty, iso, etc).
   - If you don't have git: `nix-shell -p git`
   - `sudo rm -rf /etc/nixos`
     > *Note: NixOS only uses /etc/nixos at build. If you have a preexisting configuration/secrets/etc make sure to back them up beforehand.*
   - `sudo git clone https://github.com/AnotherGitHubUsr/NixOS_headless_server.git /etc/nixos`
   - `cd /etc/nixos`
   - `sudo chmod 750 /etc/nixos/bash_shells/fix-shell-permissions.sh && sudo /etc/nixos/bash_shells/fix-shell-permissions.sh`
   - run `sudo nixos-install --flake .#nixserver`

4. **GitHub Push:**
   - Upon successful build, changes to `/etc/nixos` are pushed automagically to [this GitHub repository](https://github.com/AnotherGitHubUsr/NixOS_headless_server)
   - Commit logic handles versioning: manual for major, automatic increment for minor, if less than 24h from last commit, it's considered a patch.

5. **Disk/Disko/Labels:**
   - A storage map is created at `/etc/nixos/storage-map.txt`
   - Each disk is assigned a name of a Discworld character (see `discworld-names.nix`).
   - Disko only formats disks not already labeled as "used".
   - Bcachefs is used to cache disks provided as iSCSI devices from a NAS.
   - Write cache is flushed every 24h or if exceeding 150 GiB.

6. **Secrets in Containers:**
   See the docs for [docker-compose](https://docs.docker.com/compose/how-tos/use-secrets/) or [incus](https://linuxcontainers.org/incus/docs/main/security/) for injection best practices of age secrets.

---

## Secret Rotation and Recovery

- **Password/Token Change:**  
  Regenerate file, re-encrypt with agenix, replace in `secrets/`, rebuild.
- **Lost age key:**  
  **Cannot recover secrets.** Restore from your backup of `~/.config/agenix/age.key`.
- **Leaked secret:**  
  Revoke, rotate, and replace ASAP.

---

## Disk/Disko/Discworld Labeling

- **Discworld** character labels track all disks — only names marked as "unused" can be assigned.
- All disk operations (`disko`) are label/attribute-driven.
- `/etc/nixos/discworld-names.nix` is atomically updated nightly.
- **Sanity scripts** (`pre-disko-sanity.sh`) must be run before any destructive disk changes.
- **All disk and partition actions** are documented, labeled, and mapped at `/etc/nixos/storage-map.txt`.

---

## Monitoring, Health, AV, Logging

- **"/" On-Hours Tracking:**
    - Persistent counter (`onhours-base.txt`) stored in `/etc/nixos` and git-tracked.
    - Every 950 hours since setup: triggers fsck/scrub/clamav full scan (all local filesystems).
    - Every 2000 hours: triggers staggered SMART long test on all local drives (excluding iSCSI).
- **Every 8h:**
    - Only **detritus** is spun up.
    - All smart/sensors/firewall/journal/logsize/AV status is appended in human-readable logs to detritus.
- **Every Monday 10:30:**
    - All drives (local and iSCSI, if possible) are woken up and short SMART tests are triggered.
    - ClamAV scans only high-risk files, outputting only infected ones.
    - All logs go to detritus.

- **All log and state files are stored on detritus** for durability and are readable by default.
- Writecache of bcachefs is flushed daily at 11:00 or when size exceeds 150 GiB.

---

## NAS Integration

- NAS at `10.250.250.250` exposes 4 disks via iSCSI (mpio, persistent).
- Firewall only allows `/30` subnet comms between NAS and nixserver.
- iSCSI setup details, multipath, etc., see `disk.nix` and comments.

---

## Repo Structure

See `index.txt` and `shell-index.txt` for details on each config, module, and script.

- **Modular NixOS:** All features are in split `.nix` files imported by `configuration.nix`.
- **/bash_shells/:** All shell scripts called by systemd, activation, or for maintenance.
- **/secrets/, /credentials/, /keys/:** All strictly encrypted via agenix (never in repo).
- **/detritus/:** Logs, audit, and health data; used as the primary archive volume.

---

## References & Credits

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [agenix](https://github.com/ryantm/agenix)
- [disko](https://github.com/nix-community/disko)
- [bcachefs](https://bcachefs.org/)
- [SMART tools](https://www.smartmontools.org/)
- [ClamAV](https://www.clamav.net/)
- [CrowdSec](https://www.crowdsec.net/)

---
  
I won't be able to give support, but if you want to contact me still, I guess the best way would be:
<p align="center"><b>Contact: github.skeptic613@passinbox.com</b></p>
(this is a forwarded E-Mail. If I end up getting tons of spam I'll just disable it. Sorry)  
  
---
  
*PS:*  
*If this reads AI-written... that is because it partialls is.*  

My Workflow:  
> *Come up with logic -> Write logic in broken Nix*  
*#1 While 1*  
*{-> put in AI -> fix things AI broke (hopefully) keep things AI fixed ( if(that) {goto #2})->}*  
*#2 -> fight with AI to keep my comments -> goto #1*  
**???** *-> be happy with result -> put everything into AI to harmonize and expand comments (WITHOUT CHANGING OR DROPPING CODE!!!) -> Re-doing/adjusting comments and changed code \*sigh -> if (scopecreep) {goto #1} else if (`sudo nixos-install --flake .#nixserver`) {**???**} else {goto #1}*
<p align="center"><b>This is meant as a word of warning against using this code without reviewing it!</b></p>
