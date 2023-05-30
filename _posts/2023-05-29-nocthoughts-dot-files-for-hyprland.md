---
title: "Hyprland - NOCThoughts Dotfiles"
layout: single
classes: wide
date: 2023-05-29T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - General
  - Python
  - Automation
  - Linux
tags:
  - Python
  - Automation
  - Linux
  - Hyprland
  - Git
  - Zsh
  - Paru
---

# A Closer Look At My Dotfiles

As a Unix-based system user, I understand the crucial role that dotfiles play in shaping our system environment. <!--more-->These hidden configuration files, concealed by default, allow us to tailor our system to meet our needs perfectly. Whether it's customizing the aesthetics of our desktop environment, automating routine tasks, or configuring our favorite development environment, dotfiles are the fundamental gears turning behind the scenes of every Unix experience.

Today, I'd like to give you a tour of my own collection of dotfiles that I have stored in a repository on GitHub called "NOCThoughts-dotfiles". This repository is essentially a backup of my personal dotfiles, storing configurations for various software programs that I use. The intention behind this is simple: to set up my preferred environment seamlessly on any Unix machine.

Bear in mind, this is a work in progress. Much like many personal projects, this repository is continuously evolving. I update it as frequently as I update my local setup.

# Contents of the Repository

The repository contains dotfiles for several programs. Here are some of them:

    btop
    cava
    dunst
    hypr
    mako
    neofetch
    pipewire
    ranger
    rofi
    swaylock
    viewnior
    waybar
    wezterm
    wlogout
    wofi​

These programs cover a wide range of functionality, from system monitoring (btop) and audio visualization (cava) to file management (ranger) and terminal emulation (wezterm). Each folder in the repository's .config directory corresponds to one of these programs, and inside each folder are the specific configuration files (dotfiles) for that program.
Automation with setup.py


# Lets Automate It

To make the process of setting up my environment easier, I've created a Python script, setup.py, that automates the installation and configuration of these programs. This script installs all the necessary packages, clones the NvChad repository (a Neovim configuration I use), and copies the dotfiles to the appropriate locations in my home directory​​.

When run, setup.py goes through the following steps:

    It installs a list of packages that includes everything I need for my setup.
    It clones the NvChad repository into my ~/.config/nvim directory.
    It copies my personal configuration files to my home directory, ensuring everything is set up just the way I like it.

# Change Is Good, Backups Are Better

As a Unix user, creating, managing, and sharing dotfiles has been a rewarding experience. Not only have I been able to tailor my system exactly to my liking, but I've also been able to share my configurations with others. While it's still a work in progress, I'm excited about the evolution of my dotfiles and look forward to continually refining my setup. As I make updates to my local system, I'll continue to update my NOCThoughts-dotfiles repository. That way, no matter where I am, I can always feel right at home on any Unix machine.

# Take Me To The Dotfiles

The Dotfiles can be found on my [nocthought-dotfiles](https://github.com/Unhall0w3d/nocthoughts-dotfiles) repo on [Github]https://github.com/Unhall0w3d.

## README

# nocthoughts-dotfiles
Dotfiles for the NOCThoughts Admin. Arch _ Hyprland

# Requirements

**Arch Linux**
This script has only been tested on a base install of Arch Linux, and was built for Arch Linux.
Usage on any other distro is considered unsupported.

**python**
```zsh
pacman -Syu python
```

**git**
```zsh
pacman -Syu git
```

**paru**
```zsh
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

# Recommendations
```text
1. I recommend updating the ~/.config/hypr/hyprland.conf monitor configs to match your layout.
    a. As-is the monitor layout is two stacked "landscape" 1920x1080@144 monitors, with a 1920x1080@60 "portrait" monitor to the left.
2. SUPER+ENTER to launch Wezterm. You'll need to change your shell to zsh.
    a. sudo chsh <username> -s $(which zsh)
    b. Restart for the shell change to take effect, or source the .zshrc file.a
    c. Re-open Wezterm, with zsh as the prompt, and it should run through some plugin setup.
3. nvim/NvChad setup
    a. Set up nvchad/nvim by typing 'nvim' and walk through the setup.
4. Review ~/.conf/hypr/hyprland.conf regarding "xhost +" script that is invoked.
    a. This was used to fix some programs (Gtk primarily). If it's too insecure for you, pursue an alternative solution.
    b. Comment out the line, or remove it and the corresponding script file it points to.
    c. Otherwise, leave it alone.
5. Install "ruby" >= 2.60
    a. gem install colorls
    b. edit ~/.zshrc to add "source $(dirname $(gem which colorls))/tab_complete.sh" if desired.
```

# Installation

```zsh
cd ~/Downloads/
git clone https://github.com/Unhall0w3d/nocthoughts-dotfiles.git
cd nocthoughts-dotfiles
python setup.py
```

# Screenshots

https://imgur.com/a/mM3YFSA
