# magic tmux

This repository contains scripts for compiling tmux, zsh and neovim against glibc 2.36 and allow
them to be deployed anywhere as a simple tarball, without requiring packages to be compiled on an
older system.

This project uses the latest Arch Linux PKGBUILDs with minor patches to enable portability and
compiling against the older libc.

It supports side-by-side home and configuration directories the same way as AppImages.

The resulting archive is ~15 MB zstd-compressed.
