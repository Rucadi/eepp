{
  description = "A flake for building eepp projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    self.submodules = true;
  };

  outputs =
    {
      self,
      efsw,
      soil2,
      premakeNinja,
      premakeCMake,
      nixpkgs,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      # For each supported system, define packages and defaultPackage
      packages = builtins.listToAttrs (
        map (system: {
          name = system;
          value =
            let
              pkgs = import nixpkgs { inherit system; };
              eepp_pkgs = (
                {
                  stdenv,
                  ninja,
                  glew,
                  libx11,
                  SDL2,
                  premake5,
                  pkg-config,
                  patchelf,
                }:

                let
                  # Architecture-specific variables
                  archConfig = if stdenv.isAarch64 then "release_arm64" else "release_x86_64";
                  archLibDir = if stdenv.isAarch64 then "libs/linux/aarch64" else "libs/linux/x86_64";
                in

                stdenv.mkDerivation {
                  pname = "eepp";
                  version = "unstable";
                  src = self;

                  nativeBuildInputs = [
                    premake5
                    pkg-config
                    patchelf
                  ];

                  buildInputs = [
                    glew
                    SDL2
                    libx11
                  ];

                  configurePhase = ''

                    premake5 --disable-static-build gmake
                  '';

                  buildPhase = ''
                    make -C make/linux config=${archConfig} -j$(nproc)
                  '';

                  installPhase = ''
                    mkdir -p $out
                    cp -R ${archLibDir}/ $out/lib
                    cp -R bin $out/bin

                    find "$out/bin" -type l -lname '/build/*' -delete

                    find "$out/bin" -type f -executable -exec sh -c '
                      file "$1" | grep -q ELF && patchelf --add-rpath "'"$out/lib"'" "$1"
                    ' _ {} \;
                  '';
                }
              );
            in
            {
              eepp = pkgs.callPackage eepp_pkgs {
              };
            };
        }) systems
      );

      defaultPackage = builtins.listToAttrs (
        map (system: {
          name = system;
          value = self.packages.${system}.eepp;
        }) systems
      );
    };
}
