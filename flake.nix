{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};

    helloWorld = pkgs.writeText "hello.c" ''
      #include <stdio.h>

      int main (void) {
        printf ("Hello, world!\n");
        return 0;
      }
    '';

    # A function that takes host platform packages
    crossCompileFor = hostPkgs:
    # Run a simple command with the compiler available
      hostPkgs.runCommandCC "hello-world-cross-test" {} ''
              # Wine requires home directory

        HOME=$PWD


        # Compile our example using the compiler specific to our host platform

        mkdir $out
        $CC ${helloWorld} -o $out/hello
      '';
    pkgsWin = pkgs.pkgsCross.mingwW64;
    helloWin = crossCompileFor pkgsWin;

    emulator = pkgsWin.stdenv.hostPlatform.emulator pkgsWin.buildPackages;
    wineRun = pkgs.writeScriptBin "wine" "${emulator} $@";
    wineHello = pkgs.writeScriptBin "wine" "${emulator} ${helloWin}/out/hello";
  in {
    packages.cross.win.hello = helloWin;
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [wineRun];
    };
  };
}
