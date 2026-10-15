#!/bin/sh
# CI: build the velo540 kernel packages for one 6.12.y release inside a
# debian:trixie container, with Debian's own config for the current trixie
# kernel as the base.
#
#   kernel/ci-build.sh <6.12.y> <out-dir>
set -e
VER=$1
OUT=$2
[ -n "$VER" ] && [ -n "$OUT" ] || { echo "usage: $0 <6.12.y> <out-dir>"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q build-essential bc bison flex libssl-dev libelf-dev dwarves \
    rsync cpio kmod debhelper zstd gawk xz-utils wget ca-certificates python3

# Debian's config: from the package linux-image-amd64 currently points to
DEB=$(apt-cache depends linux-image-amd64 | awk '/Depends: linux-image-[0-9]/ {print $2; exit}')
[ -n "$DEB" ] || { echo "cannot find the trixie kernel package"; exit 1; }
echo "== base config from $DEB"
T=$(mktemp -d)
(cd "$T" && apt-get download "$DEB" && dpkg-deb --fsys-tarfile ./*.deb | tar -x --wildcards './boot/config-*')
CFG=$(ls "$T"/boot/config-* | head -n 1)
cp "$CFG" "$OUT/base-config-$(basename "$CFG" | sed 's/^config-//')"

WORK=${WORK:-/build} "$HERE/build.sh" "$CFG" "$VER"

# linux-libc-dev would replace Debian's own; only image + headers are published
cp "${WORK:-/build}"/linux-image-*velo540*.deb "${WORK:-/build}"/linux-headers-*velo540*.deb "$OUT/"
ls -la "$OUT"
