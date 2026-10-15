#!/bin/sh
# Build velo540-tools (scripts, service, mdio) and the meta packages.
#
#   pkg/build-debs.sh <out-dir> <mdio-binary> <kernel-version>
#
# linux-image-velo540  depends on linux-image-<kver>-velo540 (newest kernel),
#                      so "apt upgrade" moves to each new kernel
# velo540              depends on linux-image-velo540 + velo540-tools
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=$1
MDIO=$2
KVER=$3
[ -n "$OUT" ] && [ -x "$MDIO" ] && [ -n "$KVER" ] || {
	echo "usage: $0 <out-dir> <mdio-binary> <kernel-version>"; exit 1; }
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
TVER=$(cat "$HERE/tools/VERSION")
REV=$(git -C "$HERE" rev-list --count HEAD 2>/dev/null || echo 0)
W=$(mktemp -d)

# ---- velo540-tools
P=$W/tools
install -D -m 0755 "$HERE/tools/velo540-switch" "$P/usr/sbin/velo540-switch"
install -D -m 0755 "$HERE/tools/velo540-setup" "$P/usr/sbin/velo540-setup"
install -D -m 0755 "$MDIO" "$P/usr/sbin/mdio"
install -D -m 0644 "$HERE/tools/etc/systemd/system/velo540-switch.service" \
    "$P/usr/lib/systemd/system/velo540-switch.service"
install -D -m 0644 "$HERE/tools/etc/modules-load.d/velo540.conf" \
    "$P/usr/lib/modules-load.d/velo540.conf"
for L in "$HERE"/tools/etc/systemd/network/*.link; do
	install -D -m 0644 "$L" "$P/usr/lib/systemd/network/$(basename "$L")"
done
install -D -m 0644 "$HERE/tools/etc/default/velo540" "$P/etc/default/velo540"
mkdir -p "$P/DEBIAN"
echo /etc/default/velo540 > "$P/DEBIAN/conffiles"
cat > "$P/DEBIAN/control" <<EOF
Package: velo540-tools
Version: $TVER-$REV
Architecture: amd64
Maintainer: velo540-debian <noreply@users.noreply.github.com>
Depends: kmod, systemd
Recommends: linux-image-velo540
Section: admin
Priority: optional
Description: VeloCloud Edge 520/540 port bring-up
 Brings up the two Marvell 88E6176 switches (LAN1-8, unmanaged or DSA) and the
 88E1514 WAN PHYs (GE1/GE2) at boot, names the ports (ge1, ge2, sfp1, sfp2,
 swa/swb or lan1..lan8) and ships a static mdio tool. Needs the -velo540
 kernel (linux-image-velo540). Settings: /etc/default/velo540.
 Run velo540-setup once for the serial console and the GRUB default.
EOF
cat > "$P/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ] && [ -d /run/systemd/system ]; then
	systemctl daemon-reload || true
	systemctl enable velo540-switch.service || true
fi
if [ "$1" = configure ] && [ -z "$2" ]; then
	echo "velo540-tools: run 'velo540-setup' once (serial console + GRUB default), then reboot"
fi
exit 0
EOF
cat > "$P/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = remove ] && [ -d /run/systemd/system ]; then
	systemctl disable velo540-switch.service || true
fi
exit 0
EOF
cat > "$P/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ -d /run/systemd/system ]; then systemctl daemon-reload || true; fi
exit 0
EOF
chmod 0755 "$P/DEBIAN/postinst" "$P/DEBIAN/prerm" "$P/DEBIAN/postrm"
dpkg-deb --root-owner-group -Zxz --build "$P" "$OUT/velo540-tools_${TVER}-${REV}_amd64.deb"

# ---- meta packages
meta() {	# name version depends description
	M=$W/$1
	mkdir -p "$M/DEBIAN"
	cat > "$M/DEBIAN/control" <<EOF
Package: $1
Version: $2
Architecture: amd64
Maintainer: velo540-debian <noreply@users.noreply.github.com>
Depends: $3
Section: kernel
Priority: optional
Description: $4
 Metapackage that always depends on the newest build from the velo540
 repository, so that "apt upgrade" installs it.
EOF
	dpkg-deb --root-owner-group --build "$M" "$OUT/${1}_${2}_amd64.deb"
}
meta linux-image-velo540 "$KVER-1" "linux-image-$KVER-velo540" \
    "Linux $KVER for the VeloCloud Edge 520/540 (DSA, patched igb)"
meta linux-headers-velo540 "$KVER-1" "linux-headers-$KVER-velo540" \
    "Linux $KVER headers for the VeloCloud Edge 520/540 kernel"
meta velo540 "$TVER-$REV" "linux-image-velo540, velo540-tools" \
    "VeloCloud Edge 520/540 support (kernel + port tools)"
rm -rf "$W"
ls -la "$OUT"
