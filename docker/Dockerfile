# syntax=docker/dockerfile:1
FROM archlinux:base-devel AS build

RUN sed -i '/^SigLevel/cSigLevel = PackageRequired' /etc/pacman.conf

ARG ARCH_ARCHIVE_DATE=last
RUN echo 'https://archive.archlinux.org/repos/'${ARCH_ARCHIVE_DATE}'/$repo/os/$arch' > /etc/pacman.d/mirrorlist\\
RUN pacman -Syyuu --noconfirm \
        git \
        go \
        patchelf

# Not *great*, but do we *really* want to mess with user remapping in the Docker daemon?
ARG UID
RUN useradd -k /dev/null -md /src -U -s /usr/bin/bash -u ${UID} builduser && \
    echo 'builduser ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/local

USER builduser
WORKDIR /src
ENTRYPOINT ["bash", "./docker/build.sh"]

COPY --chown=builduser . /src/
