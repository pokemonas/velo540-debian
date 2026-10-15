#!/bin/sh
# Build a static mdio (mdio-tools, github.com/wkz/mdio-tools) on Debian.
#   tools/build-mdio.sh <out-dir> [tag]
set -e
OUT=$1
TAG=${2:-1.3.2}
[ -n "$OUT" ] || { echo "usage: $0 <out-dir> [tag]"; exit 1; }
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q build-essential autoconf automake libtool pkg-config libmnl-dev git ca-certificates
T=$(mktemp -d)
git clone -q --depth 1 --branch "$TAG" https://github.com/wkz/mdio-tools.git "$T/mdio-tools"
cd "$T/mdio-tools"
./autogen.sh > /dev/null
./configure --prefix=/usr LDFLAGS=-static > /dev/null
make -j"$(nproc)" > /dev/null
strip src/mdio/mdio
cp src/mdio/mdio "$OUT/mdio"
file "$OUT/mdio" 2>/dev/null || ls -l "$OUT/mdio"
