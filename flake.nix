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

    openclaw-default-config = pkgs.writeTextFile {
      name = "openclaw-default-config";
      text = ''
        {
          "gateway": {
            "mode": "local"
          },
          "agents": {
            "defaults": {
              "workspace": "/data"
            }
          }
        }
      '';
      destination = "/etc/openclaw/openclaw.json";
    };

    openclaw-entrypoint = pkgs.writeShellScriptBin "entrypoint" ''
      set -e

      # Create the runtime directory inside the user's mapped volume
      mkdir -p /config

      # Copy the Nix-compiled template if the user has a fresh, empty volume mount
      if [ ! -f /config/openclaw.json ]; then
        echo "[Init] Instantiating default OpenClaw config template from Nix Store..."
        cp ${openclaw-default-config}/etc/openclaw/openclaw.json /config/openclaw.json
        # Explicitly ensure the file is writeable by the active runtime user profile
        chmod 644 /config/openclaw.json
      fi

      # Handle automated token generation fallback if missing from host profile
      if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
        echo "========================================================================"
        echo "[SECURITY] OPENCLAW_GATEWAY_TOKEN was not supplied by the host profile."
        
        export OPENCLAW_GATEWAY_TOKEN=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
        
        echo "[SECURITY] Generated a secure unique random token for this container run:"
        echo ""
        echo "   👉  $OPENCLAW_GATEWAY_TOKEN  👈"
        echo ""
        echo "Please use the token above to authenticate when accessing the web GUI."
        echo "========================================================================"
      else
        echo "[Init] Loading host-provided OPENCLAW_GATEWAY_TOKEN configuration..."
      fi

      echo "[Init] Launching dynamic OpenClaw gateway on LAN interface..."

      # Launch the gateway using settings mapped in the Flake Env section
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
