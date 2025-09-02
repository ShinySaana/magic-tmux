HERE="$PWD"
SYSROOT="$PWD/sysroot"

dump_symvers() {
    nm -Du ${1:+"$1"} | grep -P 'GLIBC_2\.(3[7-9]|[4-9][0-9])'
}

extract_to_sysroot() {
    sudo bsdtar xpf ${1:+"$1"} -C "$SYSROOT" --exclude '.*'
}

do_makepkg() {
    makepkg -s --config "$HERE/makepkg.conf" --skippgpcheck "$@"
}
