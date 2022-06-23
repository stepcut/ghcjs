{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    pkgs.haskell.compiler.ghc8107
    pkgs.cabal-install
    pkgs.emscripten
    pkgs.python3
    pkgs.autoreconfHook
    pkgs.haskell.packages.ghc8107.happy_1_19_12 # has to be happy 1.19
    pkgs.haskell.packages.ghc8107.alex
  ];
}
/*
need
    pkgs.haskell.compiler.ghc8107
    pkgs.cabal-install
    pkgs.emscripten
    pkgs.python3
    pkgs.autoreconfHook
    pkgs.haskellPackages.happy_1_19_12 -- has to be happy 1.19

git submodule update --init --recursive

cd ghc
If you are in a similar situation, one workaround could be to do the ./boot; ./configure in the ghc dir.
Or you could do rm -rf ghc/.git

./utils/makePackages.sh

cabal v2-install --overwrite-policy=always --install-method=copy --installdir=inplace/bin
*/
