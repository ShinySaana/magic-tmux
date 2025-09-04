#!/usr/bin/env bash
# Dependencies:
# pacman (curl, libarchive)
# base (findutils, grep, coreutils)
# base-devel (fakeroot, patch, perl, sed)

# glibc version table
# 2.36 ~ 2022
# 2.31 ~ 2020
# 2.28 ~ 2018
#
# 2.41 (Debian 13)
# 2.36 (Debian 12)
# 2.31 (Debian 11)
# 2.39 (Ubuntu 24.04)
# 2.35 (Ubuntu 22.04)
# 2.31 (Ubuntu 20.04)
# 2.39 (RHEL 10)
# 2.34 (RHEL 9)
# 2.28 (RHEL 8)

set -euo pipefail
shopt -s extglob

ARCH=x86_64

# GLIBC_VERSION="2.31-5"
GLIBC_VERSION="2.36-7"
GLIBC_URL="https://archive.archlinux.org/packages/g/glibc/glibc-$GLIBC_VERSION-$ARCH.pkg.tar.zst"

NEOVIM_VERSION=v0.11.4
NEOVIM_URL="https://github.com/neovim/neovim/releases/download/$NEOVIM_VERSION/nvim-linux-$ARCH.tar.gz"

HERE="$(realpath "$(dirname "$0")")"

SYSROOT="$HERE/build"
PKGDIR="$HERE/pkgbuilds"
BASEDIR="$HERE/base"
CACHEDIR="$HERE/cache"
FINALDIR="$SYSROOT/final"

# dump_symvers <file>
dump_symvers() {
    nm -Du ${1:+"$1"} | grep -P 'GLIBC_2\.(3[7-9]|[4-9][0-9])'
}

# msg <args...>
msg() {
    printf "%s\n" "$@"
}

# download_file <url> [filename]
download_file() {
    local file="${2:-${1##*/}}"
    msg "downloading $file"
    curl -fsSL "$1" -o "$file"
}

# extract_to_sysroot <tar> <sysroot dir>
extract_to_sysroot() {
    msg "extracting $1 to $2"
    bsdtar -xC "$SYSROOT/$2" --exclude '.*' -f "$1"
}

patch_libc() {
    msg "patching libc paths"
    perl -pi -e "s@(/.*?(libc|ld-linux|libm))@$SYSROOT/stage1\1@g" \
        "$SYSROOT/stage1/usr/lib/libc.so" "$SYSROOT/stage1/usr/lib/libm."{a,so}
}

patch_pkgbuild() {
    [[ -f PKGBUILD ]] || return 1
    [[ -f "../../patches/${PWD##*/}.patch" ]] || return 0

    msg "patching ${PWD##*/}"
    patch -Np1 < "../../patches/${PWD##*/}.patch"
}

build_pkg() {
    msg "building ${PWD##*/}"
    makepkg -s --config "$PKGDIR/makepkg.conf" --skippgpcheck --nocheck "$@"
}

cleanbuild_pkg() {
    msg "cleaning ${PWD##*/}"
    git reset --hard HEAD
    git clean -xdff
    patch_pkgbuild
    build_pkg -f
}

# write_marker <marker>
write_marker() {
    printf "%s\n" "$1" > "$CACHEDIR/marker"
}

stage1() {
    msg "===== STAGE 1 ====="
    local glibc_tar="$CACHEDIR/glibc.tar.zst"

    [[ -f "$glibc_tar" ]] ||
        download_file "$GLIBC_URL" "$glibc_tar"

    extract_to_sysroot "$glibc_tar" stage1
    patch_libc

    msg "compiling libraries"
    (
        cd "$PKGDIR/lib"
        for pkg in */; do
            ( cd "$pkg"; cleanbuild_pkg )
        done
    )

    write_marker stage1
}

stage2() {
    msg "===== STAGE 2 ====="

    msg "extracting stage1 libraries to stage2"
    printf "%s\0" "$PKGDIR"/lib/*/!(*-doc?(s)-*).pkg.tar.* |
        xargs -0 -n1 bsdtar -xC "$SYSROOT/stage2" --exclude '.*' -f

    msg "compiling binaries"
    (
        cd "$PKGDIR/bin"
        for pkg in */; do
            ( cd "$pkg"; cleanbuild_pkg )
        done
    )

    write_marker stage2
}

stage3() {
    msg "===== STAGE 3 ====="

    local nvim_tar="$CACHEDIR/nvim.tar.gz"
    [[ -f "$nvim_tar" ]] ||
        download_file "$NEOVIM_URL" "$nvim_tar"

    msg "copying stage2 files to final directory"
    files=(
        'usr/lib/libcap.so*'
        'usr/lib/libevent_core.so*'
        'usr/lib/libgdbm.so*'
        'usr/lib/libncursesw.so*'
        'usr/lib/libpcre2-8.so*'
        'usr/share/licenses'
        'usr/share/locale'
        'usr/share/tabset'
        'usr/share/terminfo'
        usr/bin/{captoinfo,clear,infocmp,infotocap,reset,tabs,tic,toe,tput,tset}
        usr/share/man/man1/{captoinfo,clear,infocmp,infotocap,reset,tabs,tic,tput,tset}.'*'
    )
    ( cd "$SYSROOT/stage2"; cp -a --parents -- ${files[@]} "$FINALDIR" )

    msg "installing binaries to final directory"
    printf "%s\0" "$PKGDIR"/bin/*/!(*-doc?(s)-*).pkg.tar.* |
        xargs -0 -n1 bsdtar -xC "$FINALDIR" --exclude '.*' -f

    bsdtar -xC "$FINALDIR/usr" --exclude '.*' -f "$nvim_tar" --strip-components 1

    msg "copying base files to final directory"
    ( cd "$BASEDIR"; cp -a --parents * "$FINALDIR" )

    msg "cleaning up"
    files=(
        etc/skel
        usr/share/{applications,icons}
    )
    ( cd "$FINALDIR"; rm -rv -- ${files[@]} )

    write_marker stage3
}

read_marker() {
    cat "$CACHEDIR/marker"
}

# make_tarball <srcdir> <filename>
make_tarball() {
    msg "building final tarball ${1##*/}"

    local tarflags=(
        --no-fflags --no-read-sparse
        --zstd --options zstd:threads=0
        -s ',^,magic-tmux/,S' -s ',/\(config\|home\),.\1,S'
    )
    (
        cd "$FINALDIR";
        LC_COLLATE=C;
        shopt -s dotglob globstar
        printf '%s\0' **/* | fakeroot -- bsdtar -cnf "$1" ${tarflags[@]} --null --files-from -
    )
}

build() {
    local stage=$(read_marker)
    local tar="$HERE/magic-tmux.tar.zst"

    mkdir -p "$SYSROOT/stage1" "$SYSROOT/stage2" "$CACHEDIR" "$FINALDIR"
    echo '*' > "$SYSROOT/.gitignore"
    echo '*' > "$CACHEDIR/.gitignore"
    [[ -f "$CACHEDIR/marker" ]] || echo > "$CACHEDIR/marker"

    case "$stage" in
        stage1)
            stage2
            stage3
            make_tarball "$tar"
            ;;
        stage2)
            stage3
            make_tarball "$tar"
            ;;
        stage3)
            make_tarball "$tar"
            ;;
        *)
            stage1
            stage2
            stage3
            make_tarball "$tar"
            ;;
    esac
}

clean() {
    rm -r "$SYSROOT" "$CACHEDIR"
}

# reset <marker>
reset() {
    write_marker "$1"
}

# add_pkgbuild <lib|bin> <name>
add_pkgbuild() {
    [[ $1 == @(lib|bin) ]] || return 1

    git submodule add https://gitlab.archlinux.org/archlinux/packaging/packages/$2.git "$PKGDIR/$1/$2"
}

usage() {
    cat <<HELPEOF
usage: x.sh [command]

available commands:

  build                         build the project. default if no command is specified.
  clean                         clean up build and cache directories.
  reset <STAGE>                 reset build to specified STAGE
  add <lib|bin> <PACKAGE>       add PKGBUILD to project
  help                          show this text
HELPEOF
}

# main [command]
main() {
    case "${1:-build}" in
        build) build;;
        clean) clean;;
        reset) reset "$2";;
        add) add_pkgbuild "$2" "$3";;
        help|--help) usage;;
        *)
            echo "unknown command $1. see x.sh help for commands." >&2
            return 1;;
    esac
}

main "$@"
