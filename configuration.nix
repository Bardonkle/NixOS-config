{ config, pkgs, ... }:

let
  unstable = import <nixos-unstable> { config.allowUnfree = true; };
in
{
  imports = [ ./hardware-configuration.nix ];

  # ---------- Boot ----------
  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    useOSProber = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ---------- Nix ----------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  # ---------- Networking ----------
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    networkmanager.dns = "dnsmasq";
    enableIPv6 = false;
  };

  # ---------- Locale / Time ----------
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT    = "en_US.UTF-8";
    LC_MONETARY       = "en_US.UTF-8";
    LC_NAME           = "en_US.UTF-8";
    LC_NUMERIC        = "en_US.UTF-8";
    LC_PAPER          = "en_US.UTF-8";
    LC_TELEPHONE      = "en_US.UTF-8";
    LC_TIME           = "en_US.UTF-8";
  };

  # ---------- Desktop (Plasma 6 + SDDM) ----------
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;

  # ---------- Printing ----------
  services.printing.enable = true;

  # ---------- Audio (PipeWire) ----------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ---------- Graphics ----------
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # ---------- Gaming ----------
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
  programs.gamemode.enable = true;

  # ---------- Shell (zsh + Powerlevel10k) ----------
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;      # greys out a history match, accept with the right arrow
    syntaxHighlighting.enable = true;   # colors commands valid/invalid as you type
    promptInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';
  };

  # ---------- Programs ----------
  programs.firefox.enable = true;
  services.flatpak.enable = true;

  # ---------- Users ----------
  users.users.bonnsnuffles = {
    isNormalUser = true;
    description = "Ryan";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ kdePackages.kate ];
  };

  # ---------- Fonts ----------
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      liberation_ttf
      inter
    ];
    fontconfig.defaultFonts = {
      serif     = [ "Noto Serif" "Noto Serif CJK JP" ];
      sansSerif = [ "Inter" "Noto Sans CJK JP" ];
      monospace = [ "JetBrainsMono Nerd Font" "Noto Sans Mono CJK JP" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };

  # ---------- Packages ----------
  environment.systemPackages = with pkgs; [
    # shell / dev
    zsh-powerlevel10k
    nixd              # nix language server (editor autocomplete + diagnostics)
    nixfmt-rfc-style  # nix formatter nixd calls

    # gaming
    unstable.lutris
    bottles
    heroic
    mangohud
    protonup-qt
    vulkan-tools
    vkbasalt
    wineWowPackages.staging
    winetricks

    # chat
    vesktop

    # karousel + terminal
    kdePackages.karousel
    kitty

    # rice
    kdePackages.qtstyleplugin-kvantum
    papirus-icon-theme

    # utils
    git
    wget
    btop
    fastfetch
    pciutils
    ethtool
  ];

  system.stateVersion = "25.11";
}
