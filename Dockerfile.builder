# syntax=docker/dockerfile:1
FROM archlinux:base-devel AS build

ARG ARCH_ARCHIVE_DATE=last

RUN ARCH_REPO=$(printf '%s' "$ARCH_ARCHIVE_DATE" | sed -r 's/\//\\\//g') && \
    grep -E -v '^#' /etc/pacman.conf | \
    tr '\n' '\r' | \
    sed "s/\[core\][^\[]*/\[core\]\nSigLevel = PackageRequired\nServer=https:\/\/archive.archlinux.org\/repos\/${ARCH_REPO}\/\$repo\/os\/\$arch\n\n/g" | \
    sed "s/\[extra\][^\[]*/\[extra\]\nSigLevel = PackageRequired\nServer=https:\/\/archive.archlinux.org\/repos\/${ARCH_REPO}\/\$repo\/os\/\$arch\n\n/g" | \
    tr '\r' '\n' \
    > /etc/pacman.conf.new && \
    mv /etc/pacman.conf.new /etc/pacman.conf

RUN pacman -Syu --noconfirm \
        git \
        go \
        patchelf \
    && \
    useradd -k /dev/null -md /src -U -s /usr/bin/bash builduser && \
    echo 'builduser ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/local

USER builduser
WORKDIR /src

ENV IN_DOCKER=true

COPY --chown=builduser . /src/
