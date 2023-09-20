{
  description = "aercbook dev shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # required for latest zig
    zig.url = "github:mitchellh/zig-overlay";

    # Used for shell.nix
    flake-compat = {
      url = github:edolstra/flake-compat;
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    overlays = [
      # Other overlays
      (final: prev: {
        zigpkgs = inputs.zig.packages.${prev.system};
      })
    ];
    # Our supported systems are the same supported systems as the Zig binaries
    systems = builtins.attrNames inputs.zig.packages;
  in
    flake-utils.lib.eachSystem systems (
      system: let
        pkgs = import nixpkgs {inherit overlays system; };
      in rec {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            zigpkgs."0.11.0"
          ];

          buildInputs = with pkgs; [
            # we need a version of bash capable of being interactive
            # as opposed to a bash just used for building this flake 
            # in non-interactive mode
            bashInteractive 
          ];

          shellHook = ''
            # once we set SHELL to point to the interactive bash, neovim will 
            # launch the correct $SHELL in its :terminal 
            export SHELL=${pkgs.bashInteractive}/bin/bash
          '';
        };

        # For compatibility with older versions of the `nix` binary
        devShell = self.devShells.${system}.default;

        defaultPackage = packages.aercbook;

        packages.aercbook = pkgs.stdenvNoCC.mkDerivation {
          name = "aercbook";
          version = "master";
          src = ./.;
          buildInputs = [ pkgs.zigpkgs."0.11.0" ];
          dontConfigure = true;
          dontInstall = true;

          buildPhase = ''
            mkdir -p $out
            mkdir -p .cache/{p,z,tmp}
            # ReleaseSafe CPU:baseline (runs on all machines) MUSL 
            zig build install --cache-dir $(pwd)/zig-cache --global-cache-dir $(pwd)/.cache -Doptimize=ReleaseSafe -Dcpu=baseline -Dtarget=x86_64-linux-musl --prefix $out
            '';
        };

        # Usage:
        #    nix build .#docker
        #    docker load < result
        #    docker run aercbook:lastest
        # obviously, pass in cmd args and map a volume to the address book...
        packages.docker = pkgs.dockerTools.buildImage { # helper to build Docker image
          name = "aercbook";                              # give docker image a name
          tag = "latest";                               # provide a tag
          created = "now";

          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [ packages.aercbook.out ];  # .out seems to not make a difference
            pathsToLink = [ "/bin" ];
          };

          config = {
            Cmd = [ "/bin/aercbook" ];
            WorkingDir = "/bin";
          };
        };

      }
    );
  
}
