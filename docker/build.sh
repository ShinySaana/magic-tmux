#!/usr/bin/env bash

set -euo pipefail

every_presets=$(./x.sh ls)

if [ "$#" == "0" ]; then
    to_build="${every_presets}"
else
    to_build="$@"
    for preset in $to_build; do
        if [[ ! " ${every_presets[*]} " =~ [[:space:]]${preset}[[:space:]] ]]; then
            printf "magic-tmux-build: '%s' is not a valid preset!" "$preset"
            exit 1
        fi
    done
fi

for preset in $to_build; do
    PRESET="${preset}" ./x.sh build
    mv magic-tmux-${preset}.tar.zst ./output
    ./x.sh clean
done
