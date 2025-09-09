#!/usr/bin/env bash
# Dependencies:
# pacman (curl, libarchive)
# base (findutils, grep, coreutils)
# base-devel (fakeroot, patch, perl, sed)
set -euo pipefail
shopt -s extglob

# Table of various distros and their glibc+libgcc versions.
# Uses the most recent patch version available through:
#
# https://archive.archlinux.org/packages/g/glibc/
# https://archive.archlinux.org/packages/g/gcc-libs/
declare -A PRESETS=(
    [debian13]='2.41+r65+ge7c419a29575-1 14.2.1+r730+gc061ad5a36ba-1'
    [debian12]='2.36-7 12.2.1-4'
    [debian11]='2.31-5 10.2.0-6'
    [ubuntu24_04]='2.40+r66+g7d4b6bcae91f-1 14.2.1+r730+gc061ad5a36ba-1'
    [ubuntu22_04]='2.35-6 12.2.1-4'
    [ubuntu20_04]='2.31-5 10.2.0-6'
    [rhel10]='2.39+r52+gf8e4623421-1 14.2.1+r730+gc061ad5a36ba-1'
    [rhel9]='2.33-5 11.2.0-4'
    [rhel8]='2.28-6 8.3.0-1 xz'
)

PRESET="${PRESET:-debian12}"
VERSIONS=(${PRESETS[$PRESET]})

GLIBC_VERSION="${VERSIONS[0]}"
GCCLIBS_VERSION="${VERSIONS[1]}"
PKGEXT="${VERSIONS[2]:-zst}"

ARCH=x86_64

GLIBC_URL="https://archive.archlinux.org/packages/g/glibc/glibc-$GLIBC_VERSION-$ARCH.pkg.tar.$PKGEXT"
GCCLIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-$GCCLIBS_VERSION-$ARCH.pkg.tar.$PKGEXT"

HERE="$(realpath "$(dirname "$0")")"

SYSROOT="$HERE/build"
PKGDIR="$HERE/pkgbuilds"
BASEDIR="$HERE/base"
CACHEDIR="$SYSROOT/cache"
FINALDIR="$SYSROOT/final"

NEOVIM=1

# Package selection
#
# TODO: Libraries are included unconditionally right now
# under the expectation the user will want to include tmux & zsh & neovim.
if [[ -v PACKAGES ]]; then
    if [[ "$PACKAGES" == *([[:space:]]) ]]; then
        printf "Error: no packages selected." >&2
        exit 1
    fi

    for pkg in $PACKAGES; do
        if [[ ! -d "$PKGDIR/bin/$pkg" ]]; then
            printf "Error: package $pkg missing. Check spelling or run: $0 add bin $pkg" >&2
            exit 1
        fi
    done

    PACKAGES="${PACKAGES//+([[:space:]])/|}"
    PACKAGES="${PACKAGES#|}"
    PACKAGES="${PACKAGES%|}"
else
    PACKAGES="*"
fi

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

fullclean_pkg() {
    clean_pkg
    # For some reason Go decides to store packages in read-only directories...
    [[ -d src && ! -w src ]] && chmod -R u+w src
    git clean -xdff
}

clean_pkg() {
    msg "cleaning ${PWD##*/}"
    git reset --hard HEAD
}

patch_pkgbuild() {
    [[ -f PKGBUILD ]] || return 1
    [[ -f "../../patches/${PWD##*/}.patch" ]] || return 0

    msg "patching ${PWD##*/}"
    patch -Np1 < "../../patches/${PWD##*/}.patch"
}

build_pkg() {
    if [[ $(shopt -s nullglob; echo *.pkg.tar*) ]]; then
        msg "skipped building ${PWD##*/}"
    else
        msg "building ${PWD##*/}"
        makepkg --config "$PKGDIR/makepkg.conf" --syncdeps --skippgpcheck --nocheck --noconfirm "$@"
    fi
}

cleanbuild_pkg() {
    clean_pkg
    patch_pkgbuild
    build_pkg
}

# write_marker <marker>
write_marker() {
    printf "%s\n" "$1" > "$CACHEDIR/marker"
}

stage1() {
    msg "===== STAGE 1 ====="
    local glibc_tar="$CACHEDIR/glibc.tar.$PKGEXT"
    local gcclibs_tar="$CACHEDIR/gcc-libs.tar.$PKGEXT"

    [[ -f "$glibc_tar" ]] ||
        download_file "$GLIBC_URL" "$glibc_tar"

    [[ -f "$gcclibs_tar" ]] ||
        download_file "$GCCLIBS_URL" "$gcclibs_tar"

    ( cd "$SYSROOT/stage1"; find . -delete )

    extract_to_sysroot "$glibc_tar" stage1
    extract_to_sysroot "$gcclibs_tar" stage1
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

    ( cd "$SYSROOT/stage2"; find . -delete )

    msg "extracting stage1 libraries to stage2"
    printf "%s\0" "$PKGDIR"/lib/*/!(*-doc?(s)-*).pkg.tar.* |
        xargs -0 -n1 bsdtar -xC "$SYSROOT/stage2" --exclude '.*' -f

    msg "compiling binaries"
    (
        cd "$PKGDIR/bin"
        for pkg in @($PACKAGES)/; do
            ( cd "$pkg"; cleanbuild_pkg )
        done
    )

    write_marker stage2
}

patch_rpaths() {
    for file in *; do
        if file "$file" | grep -q ELF; then
            msg "patching $file"
            patchelf --force-rpath --set-rpath '$ORIGIN/../lib' "$file"
        fi
    done
}

stage3() {
    msg "===== STAGE 3 ====="

    ( cd "$FINALDIR"; find . -delete )

    msg "copying stage2 files to final directory"
    files=(
        'usr/lib/libcap.so*'
        'usr/lib/libevent_core*.so*'
        'usr/lib/libluajit*.so*'
        'usr/lib/libncursesw.so*'
        'usr/lib/libpcre2-8.so*'
        'usr/lib/lua'
        usr/share/{licenses,lua,'luajit*',tabset,terminfo}
        usr/bin/{captoinfo,clear,infocmp,infotocap,reset,tabs,tic,toe,tput,tset,'luajit*'}
        usr/share/man/man1/{captoinfo,clear,infocmp,infotocap,reset,tabs,tic,tput,tset,luajit}.'*'
    )
    ( cd "$SYSROOT/stage2"; cp -a --parents -- ${files[@]} "$FINALDIR" )

    msg "installing binaries to final directory"
    printf "%s\0" "$PKGDIR"/bin/@($PACKAGES)/!(*-doc?(s)-*).pkg.tar.* |
        xargs -0 -n1 bsdtar -xC "$FINALDIR" --exclude '.*' -f

    msg "patching rpath of binaries"
    ( cd "$FINALDIR/usr/bin"; patch_rpaths )

    msg "copying base files to final directory"
    ( cd "$BASEDIR"; cp -a --parents * "$FINALDIR" )

    msg "cleaning up"
    files=(
        etc/skel
        usr/share/{applications,bash-completion/completions/!(git),fish,fzf,icons,libalpm,metainfo,pixmaps,vim}
    )
    ( cd "$FINALDIR"; rm -rv -- ${files[@]} )
}

read_marker() {
    cat "$CACHEDIR/marker"
}

# make_tarball <srcdir> <filename>
make_tarball() {
    msg "building tarball ${1##*/}"

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

        msg "Uncompressed: $(du -bsh . | cut -f1)" \
            "Compressed:   $(du -bsh "$1" | cut -f1)"
    )
}

build() {
    local preset=$([[ -f "$CACHEDIR/preset" ]] && cat "$CACHEDIR/preset")

    if [[ -f "$CACHEDIR/preset" && "$preset" != "$PRESET" ]]; then
        msg "Preset changed ($preset -> $PRESET), forcing cleanbuild"
        clean
    fi

    mkdir -p "$SYSROOT/stage1" "$SYSROOT/stage2" "$CACHEDIR" "$FINALDIR"
    echo '*' > "$SYSROOT/.gitignore"
    [[ -f "$CACHEDIR/marker" ]] || echo > "$CACHEDIR/marker"
    [[ -f "$CACHEDIR/preset" ]] || echo "$PRESET" > "$CACHEDIR/preset"

    local stage=$(read_marker)
    local tar="$HERE/$1"

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
        *)
            stage1
            stage2
            stage3
            make_tarball "$tar"
            ;;
    esac
}

clean() {
    rm -rf "$SYSROOT"

    (
        cd "$PKGDIR"
        for pkg in lib/* bin/*; do
            ( cd "$pkg"; fullclean_pkg )
        done
    )

    # Go's build cache fucks up when switching libcs.
    go clean -cache
}

# reset <marker>
reset() {
    write_marker "$1"
}

# add_pkgbuild <lib|bin> <PACKAGE> <NAME>
add_pkgbuild() {
    [[ $1 == @(lib|bin) ]] || return 1

    (
        cd "$HERE"
        git submodule add https://gitlab.archlinux.org/archlinux/packaging/packages/$2.git "pkgbuilds/$1/$3"
    )
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

available presets (set via PRESET environment variable):

  debian13              Debian 13 (Trixie)
  debian12 [Default]    Debian 12 (Bookworm)
  debian11              Debian 11 (Bullseye)
  ubuntu24_04           Ubuntu 24.04 LTS (Noble Numbat)
  ubuntu22_04           Ubuntu 22.04 LTS (Jammy Jellyfish)
  ubuntu20_04           Ubuntu 20.04 LTS (Focal Fossa)
  rhel10                Red Hat Enterprise Linux 10
  rhel9                 Red Hat Enterprise Linux 9
  rhel8                 Red Hat Enterprise Linux 8

included packages (override via PACKAGES environment variable):

$(basename -a $HERE/pkgbuilds/bin/* | sort | awk '{ print "  " $1 }')
HELPEOF
}

# main [command]
main() {
    case "${1:-build}" in
        build) build "${2:-magic-tmux-$PRESET.tar.zst}";;
        clean) clean;;
        reset) reset "$2";;
        add) add_pkgbuild "$2" "$3" "${4:-$3}";;
        help|--help) usage;;
        *)
            echo "unknown command $1. see x.sh help for commands." >&2
            return 1;;
    esac
}

main "$@"
