#!/bin/sh
# Build a signed apt repository from a directory of .debs.
#
#   repo/build-repo.sh <deb-dir> <out-dir> [gpg-key-id]
#
# Layout: <out>/pool/main/*.deb, <out>/dists/trixie/{Release,InRelease,Release.gpg},
#         <out>/dists/trixie/main/binary-amd64/Packages(.gz), <out>/velo540.gpg (public key)
set -e
IN=$1
OUT=$2
KEY=$3
SUITE=${SUITE:-trixie}
[ -d "$IN" ] && [ -n "$OUT" ] || { echo "usage: $0 <deb-dir> <out-dir> [gpg-key-id]"; exit 1; }
mkdir -p "$OUT/pool/main" "$OUT/dists/$SUITE/main/binary-amd64"
cp "$IN"/*.deb "$OUT/pool/main/"
cd "$OUT"
apt-ftparchive packages pool/main > "dists/$SUITE/main/binary-amd64/Packages"
gzip -9nkf "dists/$SUITE/main/binary-amd64/Packages"
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=velo540 \
    -o APT::FTPArchive::Release::Label=velo540 \
    -o APT::FTPArchive::Release::Suite="$SUITE" \
    -o APT::FTPArchive::Release::Codename="$SUITE" \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    -o APT::FTPArchive::Release::Description="VeloCloud Edge 520/540 kernel and tools" \
    release "dists/$SUITE" > "dists/$SUITE/Release.tmp"
mv "dists/$SUITE/Release.tmp" "dists/$SUITE/Release"
if [ -n "$KEY" ]; then
	gpg --batch --yes -u "$KEY" --clearsign -o "dists/$SUITE/InRelease" "dists/$SUITE/Release"
	gpg --batch --yes -u "$KEY" -abs -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"
	gpg --batch --yes --export "$KEY" > velo540.gpg
	gpg --batch --yes --armor --export "$KEY" > velo540.asc
else
	echo "WARNING: unsigned repository"
fi
find . -type f | sort
