# magic tmux

This repository contains scripts for compiling tmux, zsh and neovim against glibc 2.36 and allow
them to be deployed anywhere as a simple tarball, without requiring packages to be compiled on an
older system.

This project uses the latest Arch Linux PKGBUILDs with minor patches to enable portability and
compiling against the older libc.

It supports side-by-side home and configuration directories the same way as AppImages.

The resulting archive is ~28 MB zstd-compressed and ~78 MB uncompressed:

```
   1.3 MiB   usr/lib/zsh
   2.6 MiB   usr/lib/nvim
   5.2 MiB   usr/lib
   2.1 MiB   usr/share/terminfo
   5.3 MiB   usr/share/zsh
  20.2 MiB   usr/share/nvim
  28.3 MiB   usr/share
   3.8 MiB   usr/bin/fd
   4.3 MiB   usr/bin/fzf
   5.0 MiB   usr/bin/rg
   7.9 MiB   usr/bin/direnv
  10.2 MiB   usr/bin/nvim
  11.0 MiB   usr/bin/starship
  44.2 MiB   usr/bin
  77.7 MiB   usr
  77.8 MiB   final
```

To build, run `./x.sh build`. You may be asked to install build dependencies.
