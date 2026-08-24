########################################################################
# NixOS configuration — BonnSnuffles
#
# Flake-based. Rebuild with:
#   sudo nixos-rebuild switch --flake /etc/nixos#nixos
#
# `pkgs`          -> nixos-25.11 (stable base, incl. kernel)
# `pkgs-unstable` -> nixos-unstable (cherry-picks only)
# Both are pinned in flake.lock; `nix flake update` moves them.
########################################################################

{ config, pkgs, pkgs-unstable, caelestia-shell, ... }:

let
  # Minecraft launcher.
  #   jdk8  -> 1.12-era packs (RLCraft, older FTB)
  #   jdk17 -> 1.18 - 1.20
  #   jdk21 -> 1.20.5+
  prism = pkgs.prismlauncher.override {
    jdks = with pkgs; [ jdk21 jdk17 jdk8 ];
  };

  # llama.cpp built against ROCm, for loose GGUF files Ollama can't load.
  # Unstable: ROCm support moves fast and 25.11's build lags.
  llamaCppRocm = pkgs-unstable.llama-cpp.override {
    rocmSupport = true;
  };

  # The caelestia shell package, with the CLI bundled in.
  # Its runtime deps (fish, cava, aubio, ddcutil, brightnessctl,
  # libqalculate, lm_sensors, grim, swappy, quickshell) are wrapped in
  # by the flake — do NOT list them separately in systemPackages.
  caelestiaShell = caelestia-shell.packages.${pkgs.system}.with-cli;
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
    # Resolves against stable 25.11, so this stays on a stable kernel.
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
  # Desktop sessions
  # ============================================================
  # Two sessions offered at the SDDM login screen:
  #   Plasma   — fallback / known-good, keep it until Hyprland is dialed in
  #   Hyprland — the caelestia setup
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # Steam, Discord, older game launchers
  };

  # ============================================================
  # Local AI
  # ============================================================
  # Ollama -> :11434   system service, always on
  # WebUI  -> :3000    moved off 8080
  # llama  -> :8080    manual: systemctl --user start llama-server
  services.ollama = {
    enable = true;
    package = pkgs-unstable.ollama-rocm;

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
      material-symbols            # caelestia UI icons
      nerd-fonts.caskaydia-cove   # caelestia default font
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
  # Convention: bare name = stable. `pkgs-unstable.` prefix = cherry-pick,
  # with a comment saying why.
  environment.systemPackages = with pkgs; [

    # ---------- desktop shell (hyprland / caelestia) ----------
    caelestiaShell
    wl-clipboard      # clipboard history; not bundled in the shell package
    hyprpicker        # colour picker, used by caelestia's scheme tooling
    hypridle
    hyprlock

    # ---------- editors ----------
    claude-code
    pkgs-unstable.code-cursor   # ships fast, stable lags
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
    hyprviz

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

    # ---------- infra ----------
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
    pkgs-unstable.lutris   # 25.11 pins 0.5.19
    mangohud
    prism
    protonup-qt
    vkbasalt
    vulkan-tools
    wineWowPackages.staging
    winetricks

    # ---------- desktop apps ----------
    vesktop
    kitty
    papirus-icon-theme
    zsh-powerlevel10k
    kdePackages.qtstyleplugin-kvantum
    kdePackages.karousel   # Plasma scrolling-WM; only used in the Plasma session

    # ---------- system ----------
    ethtool
    pciutils
    wget
  ];

  system.stateVersion = "25.11";
}
