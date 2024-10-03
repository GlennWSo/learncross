{
  description = "Cross compiling a rust program for windows";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane.url = "github:ipetkov/crane";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    crane,
    fenix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    toolchain = with fenix.packages.${system};
      combine [
        minimal.rustc
        minimal.cargo
        targets.x86_64-pc-windows-gnu.latest.rust-std
      ];

    craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

    # for non cross compiling, dev/test builds
    # buildsystem -> hostsystem == x86_64-linux -> x86_64-linux
    src = fetchGit {
      url = "https://github.com/emilk/eframe_template";
      rev = "4273d000067573adfe6097de62410487166e7cf3";
    };
    nativeAttrs = {
      src = src;
      buildInputs = with pkgs; [
        vulkan-loader
        wayland
        wayland-protocols
        libxkbcommon
        makeWrapper
      ];
      nativeBuildInputs = with pkgs; [
        pkg-config
        # gtk-layer-shell
        # gtk3
      ];
    };

    nativeRuntime = with pkgs; [
      alsaLib
      alsaLib.dev
      udev
      udev.dev
      libGL
      vulkan-loader
      wayland
      libxkbcommon
      pkg-config
    ];
    nativeLD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeRuntime;

    cargoArtifacts = craneLib.buildDepsOnly (nativeAttrs
      // {
        pname = "mycrate-deps";
      });

    native-nix = craneLib.buildPackage (nativeAttrs
      // {
        inherit cargoArtifacts;
        postFixup = ''
          wrapProgram $out/bin/eframe_template \
            --set LD_LIBRARY_PATH ${nativeLD_LIBRARY_PATH}
        '';
      });

    cross-win = craneLib.buildPackage {
      src = src;

      strictDeps = true;
      doCheck = false;

      CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";

      # fixes issues related to libring
      TARGET_CC = "${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/${pkgs.pkgsCross.mingwW64.stdenv.cc.targetPrefix}cc";

      #fixes issues related to openssl
      OPENSSL_DIR = "${pkgs.openssl.dev}";
      OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
      OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include/";

      depsBuildBuild = with pkgs; [
        pkgsCross.mingwW64.stdenv.cc
        pkgsCross.mingwW64.windows.pthreads
      ];
    };
  in {
    packages.${system} = {
      cross-win = cross-win;
      native-linux = native-nix;
      default = native-nix;
    };

    checks = {
      my-crate = cross-win;
    };
  };
}
