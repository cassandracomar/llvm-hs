{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs = inputs: let
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.haskell-flake.flakeModule
      ];
      perSystem = {
        self,
        system,
        config,
        pkgs,
        ...
      }: let
        callPackage = pkgs.newScope {
          haskellLib = pkgs.haskell.lib.compose;
          overrides = pkgs.haskell.packageOverrides;
          stdenv = pkgs.llvmPackages_16.libcxxStdenv;
        };
        ghc = pkgs.haskell.compiler.ghc910;
        haskellPackages = callPackage "${inputs.nixpkgs}/pkgs/development/haskell-modules" {
          inherit ghc;
          buildHaskellPackages = haskellPackages;
          compilerConfig = callPackage "${inputs.nixpkgs}/pkgs/development/haskell-modules/configuration-ghc-9.10.x.nix" {};
        };
      in {
        haskellProjects.ghc910 = {
          defaults.packages = {}; # Disable scanning for local package
          devShell.enable = false; # Disable devShells
          autoWire = []; # Don't wire any flake outputs

          basePackages = haskellPackages;
        };
        haskellProjects.default = {
          basePackages = config.haskellProjects.ghc910.outputs.finalPackages;
          projectRoot = ./.;

          settings = {
            llvm-hs = {self, ...}: {
              extraBuildTools = with pkgs.llvmPackages_16; [self.hsc2hs libllvm.dev];
              extraPkgconfigDepends = with pkgs; [zlib xml2];
              extraLibraries = with pkgs.llvmPackages_16; [libllvm.lib];
              extraConfigureFlags = with pkgs.llvmPackages_16; [
                "--ghc-option=-pgma=${libcxxStdenv.cc}/bin/as"
                "--ghc-option=-pgmc=${libcxxStdenv.cc}/bin/clang"
                "--ghc-option=-pgmcxx=${libcxxStdenv.cc}/bin/clang"
                "--ghc-option=-pgml=${libcxxStdenv.cc}/bin/clang"
                "--ghc-option=-pgmlas=${libcxxStdenv.cc}/bin/as"
                "--ghc-option=-pgmotool=${libllvm}/bin/llvm-otool"
                "--ghc-option=-pgminstall_name_tool=${libllvm}/bin/llvm-install-name-tool"
              ];
            };
          };

          devShell = {
            hlsCheck.enable = pkgs.stdenv.isDarwin;
            hoogle = true;
            tools = hs: {
              inherit (hs) cabal-install fourmolu hlint;
            };
            mkShellArgs = {
              packages = with pkgs.llvmPackages_16; [llvm libllvm libllvm.dev llvm.dev];
            };
          };
        };

        packages.stdenv = pkgs.llvmPackages_16.libcxxStdenv;
        formatter = inputs.nixpkgs.legacyPackages.${system}.alejandra;
      };
    };
}
