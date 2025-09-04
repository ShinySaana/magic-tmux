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

(generated using `erd -Cforce -dlogical -Hi -L3 -yflat build/final | grep --color=never MiB`)

The following packages are included:

- direnv
- fd
- fzf
- git-zsh-completion
- grml-zsh-config
- neovim
- ripgrep
- starship
- tmux
- zsh
- zsh-completions

Package selection can be overwritten by setting the `PACKAGES` environment variable to a space
separated list of package names (`pkgbuilds/bin/*`). Libraries are included unconditionally right
now.

You need to run `./x.sh reset stage2` after changing package selection.

As well as any libraries other than what's provided by glibc:

- libcap
- libevent
- ncurses
- pcre2

To build, run `./x.sh build`. You may be asked to install build dependencies.

Side-by-side home and configuration directories can be added to the final archive by creating and
adding files to `base/home` and `base/config` repspectively.

Global initialisation and shutdown files for tmux and zsh are read from `base/etc` only but source
the corresponding files from the system `/etc` directory by default.

## License

The original files in this repository are licensed under the BSD Zero Clause License.
See [LICENSE.txt](./LICENSE.txt) for more information.

The Arch Linux project's PKGBUILD source files are under the BSD Zero Clause License.

The created archive contains license files for the included software projects in the
`usr/share/licenses` directory. See the respective projects' PKGBUILD for information.
