{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  # for building
  buildInputs = with pkgs; [
  ];

  # for running tools in the shell
  nativeBuildInputs = with pkgs; [
    cmake
    gdb
    ninja
    qemu
    glew
  ] ++ (with llvmPackages_13; [
    clang
    clang-unwrapped
    lld
    llvm
  ]);

  hardeningDisable = [ "all" ];
}

