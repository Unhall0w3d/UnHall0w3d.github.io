---
title: "NixOS & My Configs"
layout: single
classes: wide
date: 2023-08-13T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - General
  - Linux
tags:
  - Linux
  - NixOS
  - Nix
  - Git
---

<span class="image fit"><img src="{{ "/assets/images/nixos_1.png" | absolute_url }}" alt="NixOS. It just.. keeps.. booting..." /></span>

# Well Hello There!

Howdy! Been a while, hasn't it? While you've been off, I don't know, working, living life, struggling to keep up with the verbiage anyone "younger than you" uses, binging Baldur's Gate 3... where was I? Oh, yes. While you've been off *having fun* I've been mixing things up on my desktop and laptop daily drivers and I'm now running [NixOS](https://nixos.org/)! <!--more--> Until now I've been running Arch variants with little issue and much success. So if it ain't broke, why fix it?

# NixOS

First, a brief overview of NixOS. NixOS is a Linux distribution built on top of the Nix package manager. Its declarative configuration allows reliable system upgrades via several official channels of significant size and stability. NixOS has tools dedicated to DevOps and deployment tasks.[8][9]

In short, some of the benefits of NixOS over other Linux distributions are:

    1. Abstraction: The different software packages making up a system can all be configured using the single Nix language syntax.
    2. Reproducible builds: A replica of a current system can be created on any machine with one config file.
    3. Atomic upgrades: System upgrades involve less risk of breakage, and if something does go wrong, it is simple to roll back to the previous state.
    4. Immutability: The software making up a given system configuration cannot be changed once it has been built, preventing accidental or malicious modifications.
    5. Nix package manager: Packages can be installed without affecting the rest of the system, and can be tested without installing.

# A Little Background

Now, the 'reproducible build' portion is what I was striving for with my [Arch Configs](https://github.com/Unhall0w3d/nocthoughts-dotfiles), however, it was becoming a bit to maintain and due to spending less of my time messing with CSS, Yuck, and Window Managers/Compositing, I wanted to shift to something usable, a bit familiar, and something I could repeatably deploy (if I broke something, or just felt like reformatting for one reason or another). This is where I landed on NixOS.

## What I've Done

I've installed NixOS on both my laptop and desktop and am currently differentiating the builds based on the hardware-configuration.nix file. I had a spat where I was trying to use [Home Manager](https://github.com/nix-community/home-manager), however, was running into various issues with the config files and getting my programs up and running. I have most of my go-to applications installed, and, with a quick *"nix-env -qPa | grep <package>"* I can verify if a package exists within the Nix package manager, or if I need to go to Flathub or AppImages for what I need.

I've also backed up my configurations, and will keep "live" copies on [GitHub - nixos-configs](https://github.com/Unhall0w3d/nixos-configs). It's not necessary due to the ability to boot from derivations (essentially snapshots) at boot time, however, having a backup copy I can see from the web *can* be helpful.

## What I'd Like To Do

I'd like to test more with Home Manager as a way to differentiate user based configurations, so NixOS could be deployed on (for example) my wife or son's PC with a baseline config, and user specific configs separated. I may also look into Flakes for this, as I need to look into and learn Flakes anyway. I wouldn't actually install Linux on my son or wife's PCs, both of them have turned their nose up at the... learning opportunities. A shame, truly.

As part of my exploration through NixOS there will likely be upcoming posts that go into more depth on the trials and tribulations I face. Look forward to it.

# My Configs

This brings us to my configs. If you try using the configurations you'll need to make changes to the user, hard drive mounting, packages to install, etc... I don't recommend using the configs 1:1. You can, however, take snippets that are relevant for you, such as the steam specific configurations, getting Lutris installed and working, enabling AMDGPU kernel module, etc. My configs can be found on [GitHub - nixos-configs](https://github.com/Unhall0w3d/nixos-configs).

## Configuration.nix
```zsh
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

# Main
{
  # Imports
  imports = [
        ./hardware-configuration.nix
        ];

  ## Boot Configurations
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ## 32Bit Support
  # Add support for 32Bit - opengl, pulseaudio
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  # Vulkan Support - 32Bit, OpenCL
  hardware.opengl.extraPackages = with pkgs; [
    amdvlk
    rocm-opencl-icd
    rocm-opencl-runtime
  ];

  # For 32 bit applications
  # Only available on unstable
  hardware.opengl.extraPackages32 = with pkgs; [
    driversi686Linux.amdvlk
  ];

  ## Locale/Region
  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  ## Networking
  # Hostname
    networking.hostName = "Gwyn"; # Define your hostname.

  # Enable networking
    networking.networkmanager.enable = true;

  # Enables wireless support via wpa_supplicant.
  # networking.wireless.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  ## Firewall
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  ## Desktop Environment/Window Management/Graphics
  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # HIP libraries
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.hip}"
  ];

  ## Packages
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
        "openssl-1.1.1u"
        "python-2.7.18.6"
        "electron-12.2.3"
        ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
        vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed>
        lutris
        (lutris.override {
                extraPkgs = pkgs: [
                        wineWowPackages.stable
                        winetricks
                        ];
                })
        wget
        firefox
        clinfo
        neofetch
        file
        neovim
        git
        fontconfig
        freetype
        flatpak
        openssl
        fnm
        ripgrep
        tldr
        unzip
        btop
        htop
        bat
        gparted
        ranger
        viewnior
        cava
        steam
        steam-run
        onlyoffice-bin
        etcher
        flameshot
        vscodium
        mangohud
        protonup-ng
        wine
        python3Full
        python.pkgs.pip
        qemu
        virt-manager
        jetbrains.pycharm-community
        discord
        telegram-desktop
        teams-for-linux
        ncspot
        wezterm
        spotify
        krita
        kdeconnect
        kate
        thunderbird
        conda
  ];

  # Enable ZSH
  programs.zsh.enable = true;
## Audio
  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  ## Services
  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "kennethp";

  # Virtualization Services (libvirtd // virt-viewer)
  virtualisation.libvirtd.enable = true;
  services.flatpak.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  ## User Configurations
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kennethp = {
    isNormalUser = true;
    description = "Kenneth Perry";
    extraGroups = [ "networkmanager" "wheel" "kvm" "input" "disk" "libvirtd" ];
  };

  # Set Default Shell to ZSH
  users.defaultUserShell = pkgs.zsh;

  # Add zsh to /etc/shells
  environment.shells = with pkgs; [ zsh ];

  # Fonts
  fonts = {
    fonts = with pkgs; [
      noto-fonts
      nerdfonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
      source-han-sans
      source-han-sans-japanese
      source-han-serif-japanese
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
              monospace = [ "Meslo LG M Regular Nerd Font Complete Mono" ];
              serif = [ "Noto Serif" "Source Han Serif" ];
              sansSerif = [ "Noto Sans" "Source Han Sans" ];
      };
    };
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  ## Gaming
  # Steam Firewall Configurations
  programs.steam = {
                enable = true;
                remotePlay.openFirewall = true; # open ports in firewall for Remote Play
                dedicatedServer.openFirewall = true; # open ports in firewall for Dedicated Server
        };

  ## Default Settings for Stateful Data pulled from...
  system.stateVersion = "23.05";

  ## Backups & Upgrades
  # Backup system config
  system.copySystemConfiguration = true;

  # System Upgrades
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

  ## Garbage Collection
  # Automatic Garbage Collection
  nix.gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 3d";
          };

  # Adding requirements for steam.
  # Add Steam
  nixpkgs.config.allowUnfreePredicate = true;
  nix.settings = {
    substituters = ["https://nix-gaming.cachix.org"];
    trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="];
                };

}
```

## Hardware-configuration.nix

```zsh
 Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "amdgpu" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "nvme" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
    "video=DP-1:1920x1080@144"
    "video=DP-2:1920x1080@144"
    "video=DP-3:1920x1080@60"
  ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/e623756c-d31a-4cfe-8b51-842896f5b9a0";
      fsType = "ext4";
    };

  fileSystems."/mnt/Games" =
    { device = "/dev/disk/by-uuid/304e90e3-da1c-4bc6-8ec3-3fd1c70938ce";
      fsType = "btrfs";
#      options = [ ];
  };

  fileSystems."/mnt/Elements" =
    { device = "/dev/disk/by-uuid/9ff98d32-f6ef-4226-ad80-04f14e3b842f";
      fsType = "btrfs";
#      options = [ ];
  };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/0225-D1BB";
      fsType = "vfat";
    };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp5s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Reduce Swappiness
  boot.kernel.sysctl = { "vm.swappiness" = 0;};
}
```

# And That's It

And that's mostly it! More tinkering, more learning... primarily by throwing myself into the fire with a "sink or swim" mentality, but hey... whatever works. I'd like to thank you for reading this update, feel free to join the NOC Thoughts Discord, and check back for updates!