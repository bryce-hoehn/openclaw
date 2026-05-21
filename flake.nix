{
  description = "Openclaw distroless image using nix2container";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix2container.url = "github:nlewo/nix2container";
    base.url = "github:podmania/base";
  };

  outputs = { self, nixpkgs, nix2container, base }: let
    system = builtins.currentSystem;
    pkgs = nixpkgs.legacyPackages.${system};
    n2c = nix2container.outputs.packages.${system}.nix2container;

    openclaw-entrypoint = pkgs.writeShellScriptBin "entrypoint" ''
      set -e

      if [ ! -f /config/openclaw.json ]; then
        echo "[Init] Setting up config parameters via OpenClaw Engine..."
        ${pkgs.openclaw}/bin/openclaw config set gateway.mode "local"
        ${pkgs.openclaw}/bin/openclaw config set agents.defaults.workspace "/data"
      fi

      # Auto-generate token
      if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
        echo "========================================================================"
        echo "🔒 [SECURITY] NO OPENCLAW_GATEWAY_TOKEN SUPPLIED IN THE ENVIRONMENT."
        echo "🔒 [SECURITY] GENERATING A NATIVE SECURE TOKEN VIA OPENCLAW ENGINE..."
        
        # Pure native token generation using OpenClaw's internal doctor framework
        GENERATED_TOKEN=$(${pkgs.openclaw}/bin/openclaw doctor --generate-gateway-token)
        export OPENCLAW_GATEWAY_TOKEN="$GENERATED_TOKEN"
        
        echo ""
        echo "   👉  $OPENCLAW_GATEWAY_TOKEN  👈"
        echo ""
        echo "Please copy this token to authenticate when accessing the web GUI."
        echo "========================================================================"
      else
        echo "[Init] Loading host-provided OPENCLAW_GATEWAY_TOKEN configuration..."
      fi

      echo "[Init] Launching dynamic OpenClaw gateway on LAN interface..."

      # Launch
      exec ${pkgs.openclaw}/bin/openclaw gateway run \
        --bind lan \
        --port 18789 \
        --token "$OPENCLAW_GATEWAY_TOKEN"
    '';

    imageConfig = {
      ExposedPorts = {
        "18789/tcp" = {};
      };

      Volumes = {
        "/config" = {};
        "/data" = {};
      };
      
      Env = [
        "HOME=/data"
        "XDG_CONFIG_HOME=/data/.config"
        "OPENCLAW_HOME=/config"
        "OPENCLAW_CONFIG_PATH=/config/openclaw.json"
      ];

      Cmd = [ "${openclaw-entrypoint}/bin/entrypoint" ];
    };
  in {
    packages.${system} = {
      openclaw-image = n2c.buildImage {
        name = "openclaw";
        tag = "latest";
        fromImage = base.packages.${system}.base-image;
        config = imageConfig;
      };

      openclaw-debug-image = n2c.buildImage {
        name = "openclaw";
        tag = "latest-debug";
        fromImage = base.packages.${system}.base-debug-image;
        config = imageConfig;
      };

      openclaw = pkgs.openclaw;

      default = self.packages.${system}.openclaw-image;
    };

    openclawVersion = pkgs.openclaw.version;
  };
}
