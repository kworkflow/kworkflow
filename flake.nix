{
  description = "A Nix-flake-based Node.js development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };

  outputs = { self , nixpkgs ,... }: let
    system = "x86_64-linux";
  in {
    devShells."${system}" = let
      pkgs = import nixpkgs {
	inherit system;
      }; 
    in {
      default = let
        kw_deps = with pkgs; [
	  bash
	  git
	  gnutar
	  pulseaudio
	  libpulseaudio
	  dunst
	  imagemagick
	  graphviz
	  texliveBasic
	  librsvg
	  bzip2
	  lzip
	  lzop
 	  zstd
	  xz
	  bc
	  perl
	  sqlite
	  pv
	  rsync
	  ccache
	  python3
	  dialog
	  curlFull
	  coreutils
	  b4
	  procps
	  pciutils
	  libnotify
        ];
      in 
        pkgs.mkShell {
	  packages = kw_deps;
        };	
      setup = pkgs.mkShell {
	packages = with pkgs; [
	  bash
	  git
	  gnutar
	  python3
	];
	shellHook = ''
	  bash setup.sh -i --skip-check
	'';
      };
    };
  };
}
