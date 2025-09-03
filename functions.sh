HERE="$PWD"
SYSROOT="$PWD/sysroot"
FINAL="$PWD/final"

dump_symvers() {
    nm -Du ${1:+"$1"} | grep -P 'GLIBC_2\.(3[7-9]|[4-9][0-9])'
}

extract_to_sysroot() {
    bsdtar xf ${1:+"$1"} -C "$SYSROOT/$2" --exclude '.*'
}

extract_to_final() {
    bsdtar xf ${1:+"$1"} -C "$FINAL" --exclude '.*'
}

install_libs() {
    echo "$HERE"/pkgbuilds/lib/*/!(*-doc?(s)-*).pkg.tar.* | xargs -n1 bsdtar -xC "$SYSROOT/stage2" --exclude '.*' -f
}

copy_libs() {
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
    (cd "$SYSROOT/stage2"; cp -av --parents -- ${~files} "$FINAL")
}

install_bins() {
    echo "$HERE"/pkgbuilds/bin/*/!(*-doc?(s)-*).pkg.tar.* | xargs -n1 bsdtar -xC "$FINAL" --exclude '.*' -f
    rm -rf "$FINAL"/usr/share/{applications,icons}
}

make_tarball() {
    local tarflags=(--no-fflags --no-read-sparse --zstd --options zstd:threads=0 -s ',^,magic-tmux/,S')
    (
        cd "$FINAL"; printf '%s\0' **/* |
        fakeroot -- bsdtar -cnf "$HERE/magic-tmux.tar.zst" ${tarflags[@]} --null --files-from -
    )
}

patch_pkgbuild() {
    [[ -f PKGBUILD ]] || return 1
    [[ -f "../../patches/${PWD##*/}.patch" ]] || return 0

    patch -Np1 < "../../patches/${PWD##*/}.patch"
}

do_makepkg() {
    makepkg -s --config "$HERE/makepkg.conf" --skippgpcheck --nocheck "$@"
}
