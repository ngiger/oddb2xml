{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url = "github:cachix/devenv";    
  };

  outputs = { self, nixpkgs, nixpkgs-ruby, flake-utils, devenv }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        rubyVersion = nixpkgs.lib.strings.removePrefix "ruby-"
          (nixpkgs.lib.fileContents ./.ruby-version);
        ruby = nixpkgs-ruby.packages.${system}."ruby-${rubyVersion}";       

        gems = pkgs.bundlerEnv {
          name = "gemset";
          inherit ruby;
          gemfile = ./Gemfile;
          lockfile = ./Gemfile.lock;
          gemset = ./gemset.nix;
          groups = [ "default" "production" "development" "test" ];
        };
      in
      {
        devShells = with pkgs; {
          default = mkShell {
            motd = "Ruby version is2 ${rubyVersion}";
            buildInputs = [
              # gemsls -l
              ruby
              bundix
            ];
          };
          ruby_3_1 = mkShell {
            motd = "Ruby version isg 3.1";
            buildInputs = [
              # gems
              ruby_3_1
              bundix
            ];
          };
          ruby_2_7 = mkShell {
            motd = "Ruby version isc 2.7";
            buildInputs = [
              # gems
              ruby_2_7
              bundix
            ];
          };
        };
      });
}
