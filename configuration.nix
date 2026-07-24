{ config, pkgs, ... }:

let
  # nixos-unstable channel — for packages pinned too far back in 25.11
  unstable = import <nixos-unstable> { config.allowUnfree = true; };

  # Minecraft launcher.
  #   jdk8  -> 1.12-era packs (RLCraft, older FTB)
  #   jdk17 -> 1.18 - 1.20
  #   jdk21 -> 1.20.5+
  prism = pkgs.prismlauncher.override {
    jdks = with pkgs; [ jdk21 jdk17 jdk8 ];
  };

  # llama.cpp built against ROCm, for loose GGUF files Ollama can't load.
  llamaCppRocm = unstable.llama-cpp.override {
    rocmSupport = true;
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  # ============================================================
  # Nix
  # ============================================================
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Weekly cleanup — model downloads and old generations add up fast.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [ "electron-39.8.10" ]; # vesktop
  };

  # ============================================================
  # Boot
  # ============================================================
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    loader.grub = {
      enable = true;
      device = "/dev/nvme0n1"; # legacy BIOS/MBR
      useOSProber = true;      # picks up Windows on the second NVMe
    };
  };

  # ============================================================
  # Networking
  # ============================================================
  networking = {
    hostName = "nixos";
    enableIPv6 = false;

    networkmanager = {
      enable = true;
      dns = "dnsmasq"; # local DNS cache
    };
  };

  # ============================================================
  # Locale / Time
  # ============================================================
  time.timeZone = "America/New_York";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
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
  };

  # ============================================================
  # Hardware
  # ============================================================
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # 32-bit Proton/Wine titles
  };

  # ============================================================
  # Audio (PipeWire)
  # ============================================================
  security.rtkit.enable = true;

  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ============================================================
  # Desktop (Plasma 6 + SDDM)
  # ============================================================
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;

  # ============================================================
  # Local AI
  # ============================================================
  # Ollama -> :11434   system service, always on
  # WebUI  -> :3000    moved off 8080
  # llama  -> :8080    manual: systemctl --user start llama-server
  services.ollama = {
    enable = true;
    package = unstable.ollama-rocm;
    acceleration = "rocm";

    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "0"; # unload immediately, frees VRAM
    };
  };

  # Without this Ollama can start before amdgpu is ready and fall back to CPU.
  systemd.services.ollama = {
    after = [ "systemd-udev-settle.service" ];
    wants = [ "systemd-udev-settle.service" ];
  };

  services.open-webui = {
    enable = true;
    port = 3000;
  };

  systemd.user.services.llama-server = {
    description = "llama.cpp server";

    serviceConfig = {
      ExecStart = "${llamaCppRocm}/bin/llama-server -m %h/models/Ternary-Bonsai-27B-Q2_g64.gguf --host 127.0.0.1 --port 8080 -ngl 99 -c 32768 -np 1 -fa on --poll 0 --cache-type-k q4_0 --cache-type-v q4_0";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # ============================================================
  # Services
  # ============================================================
  services.printing.enable = true;
  services.flatpak.enable = true;

  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;

  # ============================================================
  # Programs
  # ============================================================
  programs.firefox.enable = true;
  programs.nix-ld.enable = true; # FHS shim for vendor binaries

  # Auto-loads a project's shell.nix on cd.
  # Use with: echo "use nix" > .envrc && direnv allow
  programs.direnv.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    interactiveShellInit = ''
      setopt interactive_comments
    '';
    promptInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';
  };

  # ============================================================
  # Gaming
  # ============================================================
  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  # ============================================================
  # Users
  # ============================================================
  users.users.bonnsnuffles = {
    isNormalUser = true;
    description = "Ryan";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [ kdePackages.kate ];
  };

  # ============================================================
  # Fonts
  # ============================================================
  fonts = {
    enableDefaultPackages = true;

    packages = with pkgs; [
      inter
      liberation_ttf
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];

    fontconfig.defaultFonts = {
      serif     = [ "Noto Serif" "Noto Serif CJK JP" ];
      sansSerif = [ "Inter" "Noto Sans CJK JP" ];
      monospace = [ "JetBrainsMono Nerd Font" "Noto Sans Mono CJK JP" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };

  # ============================================================
  # Packages
  # ============================================================
  environment.systemPackages = with pkgs; [

    # ---------- editors ----------
    claude-code
    unstable.code-cursor
    vscode
    zed-editor

    # ---------- languages ----------
    python313
    uv                # fast pip/venv replacement, plays well with NixOS
    nodejs_24
    pnpm
    rustc
    cargo
    go
    jdk21
    dotnet-sdk_9
    gcc
    clang
    sqlite
    delve
   
    # ---------- build & debug ----------
    gnumake
    cmake
    ninja
    pkg-config
    gdb
    valgrind

    # ---------- language servers & formatters ----------
    nixd
    nixfmt-rfc-style
    clang-tools       # clangd + clang-format
    pyright
    ruff              # python lint + format
    rust-analyzer
    rustfmt
    clippy
    gopls
    typescript-language-server
    csharp-ls
    nodePackages.prettier
    kind
    kubectl
    terraform
    # ---------- git ----------
    git
    gh
    lazygit
    delta             # better diffs

    # ---------- cli ----------
    ripgrep           # rg
    fd
    bat
    eza
    tree
    jq
    unzip
    btop
    fastfetch

    # ---------- local AI ----------
    llamaCppRocm
    python3Packages.huggingface-hub

    # ---------- gaming ----------
    bottles
    heroic
    unstable.lutris   # 25.11 pins 0.5.19
    mangohud
    prism
    protonup-qt
    vkbasalt
    vulkan-tools
    wineWowPackages.staging
    winetricks

    # ---------- desktop ----------
    vesktop
    kdePackages.karousel
    kdePackages.qtstyleplugin-kvantum
    kitty
    papirus-icon-theme
    zsh-powerlevel10k

    # ---------- system ----------
    ethtool
    pciutils
    wget
  ];

  system.stateVersion = "25.11";
}
