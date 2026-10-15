# velo540-debian

Debian 13 (trixie) on the **VeloCloud Edge 520/540**: a 6.12 LTS kernel with
the board patches and DSA, plus the port bring-up service, as an apt
repository that GitHub Actions keeps up to date.

| Jacks      | Interface (DSA_MASK=0) | Interface (DSA_MASK=3) | Hardware                    |
|------------|------------------------|------------------------|-----------------------------|
| LAN1–4     | swb                    | lan1 … lan4            | 88E6176 switch B, i354 14.1 |
| LAN5–8     | swa                    | lan5 … lan8            | 88E6176 switch A, i354 14.0 |
| GE1, GE2   | ge1, ge2               | ge1, ge2               | 88E1514 PHYs, i354 14.2/14.3|
| SFP1, SFP2 | sfp1, sfp2             | sfp1, sfp2             | i350 04:00.0/.1             |

## Install on the box

```
sudo install -d /usr/share/keyrings
curl -fsSL https://OWNER.github.io/velo540-debian/velo540.gpg | sudo tee /usr/share/keyrings/velo540.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/velo540.gpg] https://OWNER.github.io/velo540-debian trixie main" |
    sudo tee /etc/apt/sources.list.d/velo540.list
sudo apt update
sudo apt install velo540
sudo velo540-setup        # serial console on ttyS1 (micro-USB) + GRUB default = -velo540
sudo reboot
```

Every new 6.12.y arrives with `apt upgrade` (`linux-image-velo540` always
depends on the newest kernel). Check after a reboot:
`uname -r` (…-velo540), `journalctl -u velo540-switch`, `ip -br link`.

Per-jack interfaces (DSA): set `DSA_MASK=3` in `/etc/default/velo540`, reboot.

## Packages

| Package                 | Contents |
|-------------------------|----------|
| `linux-image-<ver>-velo540`, `linux-headers-<ver>-velo540` | kernel from kernel.org 6.12.y, Debian's trixie config + NET_DSA, MV88E6XXX, MDIO/I2C GPIO, GPIO_ICH, PCA953X; patches 200–230 and the velocloud glue modules |
| `linux-image-velo540`, `linux-headers-velo540` | metapackages → newest kernel |
| `velo540-tools`         | `velo540-switch` (+ systemd service), `velo540-setup`, static `mdio`, port names (`.link`), `/etc/default/velo540` |
| `velo540`               | installs both |

## How the CI works

`.github/workflows/build.yml`, daily and on push:

1. **check** – newest 6.12.y on kernel.org; build if there is no
   `kernel-<ver>` release yet.
2. **kernel** – in a `debian:trixie` container: takes the config of the
   kernel Debian currently ships (`linux-image-amd64` → its `/boot/config-*`),
   runs `kernel/build.sh` (patches, config options, `make bindeb-pkg`) and
   attaches image + headers to the release `kernel-<ver>` (1–3 h).
3. **publish** – downloads the newest `KEEP` (2) kernels, builds `mdio`,
   `velo540-tools` and the metapackages, signs the apt repository with the
   `APT_SIGNING_KEY` secret and deploys it to GitHub Pages.

Manual run for a given version: *Actions → build → Run workflow → kernel*.

## Setup of the GitHub repository (once)

1. Public repository `velo540-debian`, push this tree to `main`.
2. Signing key (keep the exported file offline as a backup):
   ```
   gpg --batch --pinentry-mode loopback --passphrase '' \
       --quick-gen-key "velo540 apt <noreply@users.noreply.github.com>" rsa4096 sign never
   gpg --armor --export-secret-keys "velo540 apt" > velo540-apt.key
   gh secret set APT_SIGNING_KEY < velo540-apt.key
   ```
3. Pages: `gh api -X POST repos/{owner}/{repo}/pages -f build_type=workflow`
4. `gh workflow run build.yml` – the first run builds a kernel (1–3 h).

## Building by hand

```
sudo apt install build-essential bc bison flex libssl-dev libelf-dev dwarves \
    rsync cpio kmod debhelper zstd gawk xz-utils wget
kernel/build.sh /boot/config-$(uname -r) 6.12.112          # full, hours
kernel/build.sh /boot/config-$(uname -r) 6.12.112 fast     # only modules in kernel/velobox.lsmod
```

## Credits

Patches and register sequences from
[velo540openwrt](https://github.com/gallops-gannets/velo540openwrt);
[mdio-tools](https://github.com/wkz/mdio-tools) by Tobias Waldekranz.
