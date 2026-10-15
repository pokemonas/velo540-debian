#!/bin/sh
# Build a Debian kernel package for the VeloCloud Edge 520/540 with DSA.
#
#   ./build.sh <debian-config> [kernel-version] [fast]
#
#   <debian-config>   /boot/config-*-amd64 copied from the velobox (Debian's own config)
#   kernel-version    6.12.x from kernel.org (default 6.12.112, the tested one),
#                     or "latest" = newest 6.12.y listed on kernel.org
#   fast              build only the modules listed in ./velobox.lsmod (lsmod output
#                     from the velobox) + the board modules: ~20 min instead of hours,
#                     but anything not loaded at lsmod time is missing later
#
# Runs on any x86-64 Debian/Ubuntu/Mint machine.  Needs ~20 GB free (~5 GB fast).
# Env WORK=<dir>: where the kernel tree is unpacked and the .debs land
# (default: this directory).  The CI runs it via ci-build.sh.
# Result: $WORK/linux-image-<version>-velo540_*.deb -> dpkg -i on the velobox.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
CFG=$1
VER=${2:-6.12.112}
MODE=$3
[ -r "$CFG" ] || { echo "usage: $0 <debian-config> [6.12.x] [fast]"; exit 1; }
CFG=$(cd "$(dirname "$CFG")" && pwd)/$(basename "$CFG")
if [ "$VER" = latest ]; then
	VER=$(wget -qO- https://www.kernel.org/releases.json | grep -o '"6\.12\.[0-9]*"' | tr -d '"' | sort -V | tail -1)
	[ -n "$VER" ] || { echo "could not find the latest 6.12.y on kernel.org"; exit 1; }
	echo "== latest 6.12.y: $VER"
fi

need="build-essential bc bison flex libssl-dev libelf-dev dwarves rsync cpio kmod debhelper zstd gawk xz-utils wget"
missing=""
for p in $need; do dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"; done
[ -z "$missing" ] || { echo "install first: sudo apt install$missing"; exit 1; }

WORK=${WORK:-$HERE}
mkdir -p "$WORK"
cd "$WORK"
SRC=linux-$VER
if [ ! -d "$SRC" ]; then
	[ -f "$SRC.tar.xz" ] || wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/$SRC.tar.xz"
	echo "== unpacking $SRC"
	tar xJf "$SRC.tar.xz"
	cd "$SRC"
	echo "== patches"
	for p in "$HERE"/patches/*.patch; do
		echo "   $(basename "$p")"
		patch -p1 --forward --no-backup-if-mismatch < "$p"
	done
	cp "$HERE/patches/igb_vc.c" drivers/net/ethernet/intel/igb/igb_vc.c
	cp -r "$HERE/patches/velocloud" drivers/platform/x86/
	echo 'obj-y += velocloud/' >> drivers/platform/x86/Makefile
	cd ..
fi
cd "$SRC"

echo "== config: Debian's + DSA + board drivers"
cp "$CFG" .config
S=scripts/config
$S --set-str LOCALVERSION "-velo540" --disable LOCALVERSION_AUTO \
   --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" \
   --disable MODULE_SIG_ALL --disable DEBUG_INFO --disable DEBUG_INFO_DWARF5 \
   --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT --disable DEBUG_INFO_BTF --enable DEBUG_INFO_NONE \
   --module NET_DSA --module NET_DSA_MV88E6XXX --module NET_DSA_TAG_DSA --module NET_DSA_TAG_EDSA \
   --module MDIO_BITBANG --module MDIO_GPIO --module GPIO_ICH --module LPC_ICH \
   --module I2C_GPIO --module GPIO_PCA953X --module LEDS_PCA963X --module IGB \
   --enable GPIO_SYSFS
make olddefconfig >/dev/null
if [ "$MODE" = fast ]; then
	[ -r "$HERE/velobox.lsmod" ] || { echo "fast mode needs $HERE/velobox.lsmod (lsmod > velobox.lsmod on the velobox)"; exit 1; }
	echo "== fast: localmodconfig from velobox.lsmod"
	make LSMOD="$HERE/velobox.lsmod" localmodconfig </dev/null >/dev/null
	$S --module NET_DSA --module NET_DSA_MV88E6XXX --module NET_DSA_TAG_DSA --module NET_DSA_TAG_EDSA \
	   --module MDIO_BITBANG --module MDIO_GPIO --module GPIO_ICH --module LPC_ICH \
	   --module I2C_GPIO --module GPIO_PCA953X --module LEDS_PCA963X --module IGB \
	   --module BRIDGE --module VETH --module OVERLAY_FS --module TUN --module WIREGUARD
	make olddefconfig >/dev/null
fi
for o in NET_DSA NET_DSA_MV88E6XXX NET_DSA_TAG_DSA MDIO_GPIO GPIO_ICH I2C_GPIO GPIO_PCA953X IGB; do
	grep -q "^CONFIG_$o=[ym]" .config || { echo "CONFIG_$o did not stick"; exit 1; }
done

echo "== building $(make -s kernelversion)-velo540 with $(nproc) jobs (this takes a while)"
make -j"$(nproc)" bindeb-pkg KDEB_PKGVERSION="$VER-1velo540" INSTALL_MOD_STRIP=1
echo
ls -la "$WORK"/linux-image-*velo540*.deb
