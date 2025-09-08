# syntax=docker/dockerfile:1
FROM archlinux:base-devel

RUN <<EOF
pacman -Syu --noconfirm git
useradd -k /dev/null -md /src -U -s /usr/bin/bash builduser
echo 'builduser ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/local
EOF

USER builduser
WORKDIR /src

COPY --chown=builduser . /src/
RUN git submodule update --init

ENTRYPOINT bash -l
