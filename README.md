# OffSec-Toolkit | OTK

A practical, environment-aware installer for a collection of offensive-security, penetration-testing, security-auditing, OSINT, wireless, password-auditing, and web-security tools on Debian-based Linux systems.

**OffSec-Toolkit** is shortened to **OTK** for command-line and project branding.

![OffSec-Toolkit](https://github.com/siafulinux/hack-tools/blob/main/Hack%20Tools.png)

---

## Overview

**OffSec-Toolkit (OTK)** automates the installation of a practical collection of security tools while being designed to coexist with existing Debian-based security environments.

OTK can be used on:

- Debian
- Ubuntu
- Kali Linux
- Parrot OS
- Linux Mint
- Pop!_OS
- Other compatible Debian-based distributions

The installer is designed to be **idempotent and environment-aware**. Rather than assuming the system is empty, OTK checks for tools that are already installed before attempting to install them.

This makes it suitable for both relatively clean Debian installations and established security-focused distributions such as Kali Linux and Parrot OS.

---

## Features

### 🔎 Existing Tool Detection

OTK checks for existing tools using multiple methods:

- Debian/Ubuntu package database
- Executables already available in `$PATH`
- Known installation locations
- Existing Git repositories
- Existing wordlists
- Existing PTF installations
- Existing Burp Suite installations
- Existing Metasploit installations

If a tool is already present, OTK skips it instead of unnecessarily installing another copy.

---

### 🛡️ Security-Distribution Awareness

OTK specifically detects:

- Kali Linux
- Parrot OS

When an existing security distribution is detected, OTK takes a more conservative approach.

OTK does **not**:

- Add Kali repositories
- Add Parrot repositories
- Replace existing APT repositories
- Install Kali or Parrot metapackages
- Remove existing security tools
- Automatically perform a full system upgrade
- Deliberately overwrite existing tool installations

The goal is to add useful missing tools without turning an existing security workstation into a package-management tug-of-war.

---

### 🔄 Safe to Re-Run

OTK is designed to be safely re-run.

Existing installations are detected and skipped whenever possible.

For example:

```text
[=] Nmap is already installed through APT.
[=] Hashcat is already installed through APT.
[=] Burp Suite already exists in PATH.
[=] SecLists already exists.
