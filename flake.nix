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
    imageConfig = {
      ExposedPorts = {
        
        "18789/tcp" = {};
        
      };
      Volumes = {
        
      };
      
      Cmd = [ "${pkgs.openclaw}/bin/openclaw" ];
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
