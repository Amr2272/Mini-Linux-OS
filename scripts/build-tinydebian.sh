#!/bin/bash
set -e

# TinyDebian Live - USB distro builder
# XFCE desktop, Firefox, Gemini CLI, persistence, audio
# VMware clipboard (copy/paste host <-> guest)
# makes a hybrid iso you can dd straight to a usb stick

echo "=== TinyDebian Builder ==="
echo ""

# --- cleanup mounts when we exit, no matter what ---
cleanup() {
    umount -lf "$WORK_DIR/chroot/dev/pts" 2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/dev"     2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/proc"    2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/sys"     2>/dev/null || true
    umount -lf "$WORK_DIR/chroot/run"     2>/dev/null || true
}
trap cleanup EXIT

# gotta be root
if [ "$EUID" -ne 0 ]; then
    echo "run this with sudo"
    exit 1
fi

# --------------- config ---------------
WORK_DIR="${BUILD_DIR:-$HOME/tiny-debian-build}"
ARCH=$(dpkg --print-architecture)
ISO_OUTPUT="${WORK_DIR}/TinyDebian-${ARCH}.iso"

# need at least 15gb free or the squashfs step will choke
AVAIL=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAIL" -lt 15 ]; then
    echo "not enough space, need 15GB free, you have ${AVAIL}GB"
    exit 1
fi

# --------------- step 1: directories ---------------
echo "[1/10] setting up directories..."
if [ -d "$WORK_DIR/chroot" ]; then
    cleanup
    sleep 1
fi
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{chroot,iso/live,scratch}

# --------------- step 2: host tools ---------------
echo "[2/10] installing build tools on host..."
apt-get update -o Acquire::ForceIPv4=true
apt-get install -y debootstrap squashfs-tools xorriso isolinux syslinux-efi \
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools

# --------------- step 3: bootstrap ---------------
echo "[3/10] bootstrapping debian bookworm..."
debootstrap --arch=$ARCH --variant=minbase bookworm "$WORK_DIR/chroot" \
    http://deb.debian.org/debian

# --------------- step 4: base config ---------------
echo "[4/10] configuring the chroot..."

cat > "$WORK_DIR/chroot/etc/apt/sources.list" <<'EOF'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
EOF

echo "TinyDebian" > "$WORK_DIR/chroot/etc/hostname"

cat > "$WORK_DIR/chroot/etc/hosts" <<'EOF'
127.0.0.1   localhost
127.0.1.1   TinyDebian
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# mount what chroot needs
mount --bind /dev     "$WORK_DIR/chroot/dev"
mount --bind /dev/pts "$WORK_DIR/chroot/dev/pts"
mount --bind /proc    "$WORK_DIR/chroot/proc"
mount --bind /sys     "$WORK_DIR/chroot/sys"
mkdir -p "$WORK_DIR/chroot/run"
mount --bind /run     "$WORK_DIR/chroot/run"

for mp in dev proc sys; do
    mountpoint -q "$WORK_DIR/chroot/$mp" || { echo "failed to mount $mp"; exit 1; }
done

chmod 666 "$WORK_DIR/chroot/dev/null" 2>/dev/null || true
chmod 666 "$WORK_DIR/chroot/dev/zero" 2>/dev/null || true

# --------------- step 5: the big install script inside chroot ---------------
# everything from here to CHROOT_EOF runs inside the new system
cat > "$WORK_DIR/chroot/install.sh" <<'CHROOT_EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

echo "test" > /dev/null 2>&1 || { echo "/dev/null broken"; exit 1; }

# ---- kernel + live-boot stuff ----
echo "installing kernel and live-boot..."
apt-get update -o Acquire::ForceIPv4=true
apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    live-boot \
    live-boot-initramfs-tools \
    live-config \
    live-config-systemd \
    systemd-sysv \
    live-tools \
    rsync
apt-get clean
rm -rf /var/lib/apt/lists/*

# ---- wifi / network ----
echo "installing network stuff..."
apt-get update -o Acquire::ForceIPv4=true
apt-get install -y --no-install-recommends \
    network-manager \
    network-manager-gnome \
    wireless-tools \
    wpasupplicant \
    iw \
    firmware-iwlwifi \
    firmware-realtek \
    firmware-atheros \
    firmware-misc-nonfree
apt-get clean
rm -rf /var/lib/apt/lists/*

# ---- xfce + audio ----
echo "installing desktop and audio..."
apt-get update -o Acquire::ForceIPv4=true
apt-get install -y --no-install-recommends \
    xserver-xorg-core \
    xserver-xorg-input-all \
    xserver-xorg-video-fbdev \
    xserver-xorg-video-vesa \
    xserver-xorg-video-intel \
    xserver-xorg-video-amdgpu \
    xserver-xorg-video-nouveau \
    xfce4 \
    xfce4-terminal \
    xfce4-settings \
    thunar \
    mousepad \
    xfce4-screenshooter \
    xfce4-taskmanager \
    xarchiver \
    dbus-x11 \
    libgtk-3-0 \
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    pavucontrol \
    playerctl \
    gvfs \
    gvfs-backends \
    gvfs-fuse \
    x11-xserver-utils
apt-get clean
rm -rf /var/lib/apt/lists/*

# ---- apps: firefox, gparted, the usual suspects ----
echo "installing firefox and other apps..."
apt-get update -o Acquire::ForceIPv4=true
apt-get install -y --no-install-recommends \
    sudo \
    nano \
    vim-tiny \
    htop \
    gparted \
    synaptic \
    zenity \
    wget \
    curl \
    ca-certificates \
    git \
    unzip \
    zip \
    file-roller \
    parted \
    util-linux \
    firefox-esr \
    locales \
    keyboard-configuration \
    console-setup \
    dosfstools \
    ntfs-3g \
    exfat-fuse \
    exfatprogs
apt-get clean
rm -rf /var/lib/apt/lists/*

# ---- vmware tools + clipboard stuff ----
# open-vm-tools-desktop is the one that matters here — it ships the
# X11 clipboard plugin. without it copy/paste between host and guest
# just doesn't work in VMware. xclip and xsel are there too so you
# can copy/paste from the terminal if you need to.
echo "installing vmware tools and clipboard packages..."
apt-get update -o Acquire::ForceIPv4=true
apt-get install -y --no-install-recommends \
    open-vm-tools \
    open-vm-tools-desktop \
    xclip \
    xsel
apt-get clean
rm -rf /var/lib/apt/lists/*

# ---- node 22 from nodesource (bookworm ships 18 which is too old) ----
echo "installing node 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y --no-install-recommends nodejs
apt-get clean
rm -rf /var/lib/apt/lists/*

# ---- gemini cli ----
echo "installing gemini cli..."
npm install -g @google/gemini-cli
command -v gemini && echo "gemini ok" || echo "WARNING: gemini not found after install"

# ---- lightdm ----
echo "installing lightdm..."
apt-get update -o Acquire::ForceIPv4=true
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends lightdm
apt-get clean
rm -rf /var/lib/apt/lists/*

# ============================================================
# user setup
# ============================================================
echo "creating live user..."
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev live 2>/dev/null || true
echo "live:live" | chpasswd
echo "live ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/live
chmod 440 /etc/sudoers.d/live

# ============================================================
# lightdm autologin
# ============================================================
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/01-autologin.conf <<'LIGHTDM_EOF'
[Seat:*]
autologin-user=live
autologin-user-timeout=0
user-session=xfce
LIGHTDM_EOF

# ============================================================
# keyboard - english + arabic, alt+shift to toggle
# ============================================================
cat > /etc/default/keyboard <<'KEYBOARD_EOF'
XKBMODEL="pc105"
XKBLAYOUT="us,ara"
XKBVARIANT=","
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
KEYBOARD_EOF

mkdir -p /home/live/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/live/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml <<'XFCE_KB_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="keyboard-layout" version="1.0">
  <property name="Default" type="empty">
    <property name="XkbDisable" type="bool" value="false"/>
    <property name="XkbLayout" type="string" value="us,ara"/>
    <property name="XkbVariant" type="string" value=","/>
    <property name="XkbOptions" type="empty">
      <property name="Group" type="string" value="grp:alt_shift_toggle"/>
    </property>
  </property>
</channel>
XFCE_KB_EOF

# ============================================================
# resolution fix - picks the best resolution xrandr finds,
# falls back to 1024x768 if nothing works.
# runs once on every login so VMs resize properly too.
# ============================================================
cat > /usr/local/bin/fix-resolution <<'RESCODE'
#!/bin/bash
# try to find and set a good resolution automatically
# this handles VMs that start at 800x600 and real hardware alike

PREFERRED=$(xrandr | grep -oP '\d{3,4}x\d{3,4}' | head -1)

if [ -z "$PREFERRED" ]; then
    # xrandr couldn't even list modes, try a forced set
    xrandr --mode 1024x768 2>/dev/null || true
    exit 0
fi

# if we already have something reasonable (1024 or higher width) leave it
CURRENT_W=$(echo "$PREFERRED" | cut -dx -f1)
if [ "$CURRENT_W" -ge 1024 ] 2>/dev/null; then
    # already fine, but still set it explicitly so scaling is right
    xrandr --mode "$PREFERRED" 2>/dev/null || true
    exit 0
fi

# try common resolutions from big to small until one sticks
for res in 1920x1080 1680x1050 1440x900 1366x768 1280x800 1280x720 1024x768; do
    if xrandr | grep -q "$res"; then
        xrandr --mode "$res" 2>/dev/null && exit 0
    fi
done

# nothing matched, just use whatever xrandr said first
xrandr --mode "$PREFERRED" 2>/dev/null || true
RESCODE
chmod +x /usr/local/bin/fix-resolution

# put it in xfce autostart so it runs on every login
mkdir -p /home/live/.config/autostart
cat > /home/live/.config/autostart/fix-resolution.desktop <<'AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=Fix Resolution
Exec=/usr/local/bin/fix-resolution
Hidden=false
OnlyShowIn=XFCE;
X-XFCE-Autostart-Enabled=true
AUTOSTART_EOF

# ============================================================
# vmware clipboard helper
# this is a small script that kicks off vmtoolsd in the background
# after X is up. it's the thing that actually makes copy/paste work
# between the VM and your windows/mac host. if you're not running
# in VMware it just exits quietly, no harm done.
# also does a quick sanity check and logs what's going on so if
# someone reports "clipboard broken" we have something to look at.
# ============================================================
cat > /usr/local/bin/vmware-clipboard-init <<'VMCLIP_EOF'
#!/bin/bash
# vmware clipboard init — runs at login via autostart
# does nothing if we're not in a VM, so it's safe to leave on bare metal

LOGFILE="/tmp/vmware-clipboard.log"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOGFILE"
}

log "starting clipboard init"

# first check: are we actually in a VMware VM?
# dmi product name will say "VMware Virtual Platform" if we are
if [ -f /sys/class/dmi/id/product_name ]; then
    PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    if [[ "$PRODUCT" != *VMware* ]]; then
        log "not VMware ($PRODUCT), exiting"
        exit 0
    fi
else
    # can't read dmi, try vmtoolsd --cmd as a fallback check
    if ! command -v vmtoolsd &>/dev/null; then
        log "no vmtoolsd found, exiting"
        exit 0
    fi
fi

log "detected VMware, setting up clipboard"

# make sure vmtoolsd is actually running
if ! pgrep -x vmtoolsd &>/dev/null; then
    log "vmtoolsd not running, starting it"
    vmtoolsd &
    sleep 2
fi

# double check it's up now
if pgrep -x vmtoolsd &>/dev/null; then
    log "vmtoolsd is running, clipboard should work"
    log "pid: $(pgrep -x vmtoolsd)"
else
    log "WARNING: vmtoolsd still not running after start attempt"
    log "try running 'sudo systemctl restart vmtoolsd' manually"
fi

# also make sure the vmware-toolbox-cmd stuff is happy
if command -v vmware-toolbox-cmd &>/dev/null; then
    vmware-toolbox-cmd config set deployconfig enable-custom-scripts TRUE 2>/dev/null
    log "toolbox config updated"
fi

log "clipboard init done"
VMCLIP_EOF
chmod +x /usr/local/bin/vmware-clipboard-init

# autostart entry for the clipboard helper — runs after desktop is up
cat > /home/live/.config/autostart/vmware-clipboard.desktop <<'VMCLIP_AUTO_EOF'
[Desktop Entry]
Type=Application
Name=VMware Clipboard
Comment=Enables copy/paste between VM and host
Exec=/usr/local/bin/vmware-clipboard-init
Hidden=false
OnlyShowIn=XFCE;
X-XFCE-Autostart-Enabled=true
X-XFCE-Autostart-Delay=3
VMCLIP_AUTO_EOF

# ============================================================
# persistence setup wizard
# the user runs this once after first boot to create the
# persistence partition. after that live-boot handles everything.
# ============================================================
cat > /usr/local/bin/setup-persistence <<'PERSIST_EOF'
#!/bin/bash

# already running with persistence? nothing to do
if [ -d /live/persistence ]; then
    zenity --info --title="Persistence" \
        --text="Persistence is already active. Your changes are being saved." 2>/dev/null \
        || echo "persistence is already active"
    exit 0
fi

echo "============================================="
echo "  TinyDebian Persistence Setup"
echo "============================================="
echo ""

# figure out which device we booted from
BOOT_DEVICE=""
LIVE_MEDIA=$(grep -o 'live-media=[^ ]*' /proc/cmdline 2>/dev/null | cut -d= -f2)
[ -n "$LIVE_MEDIA" ] && BOOT_DEVICE="/dev/$LIVE_MEDIA"

# backup method: check where /lib/live/mount/medium is mounted
if [ -z "$BOOT_DEVICE" ]; then
    BOOT_DEVICE=$(df /lib/live/mount/medium 2>/dev/null | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
fi

if [ -n "$BOOT_DEVICE" ] && [ -b "$BOOT_DEVICE" ]; then
    echo "boot device: $BOOT_DEVICE"
    BOOT_USB=true
else
    echo "couldn't detect boot device"
    BOOT_USB=false
fi
echo ""

echo "disks on this system:"
sudo lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT | grep -v loop
echo ""

# pick what to do
if [ "$BOOT_USB" = true ]; then
    echo "[1] create persistence on the boot USB ($BOOT_DEVICE) - recommended"
    echo "[2] use a different drive for persistence"
    echo "[3] pick the device manually"
    echo ""
    read -p "choice [1/2/3]: " option
else
    echo "can't auto-detect, going manual"
    option=3
fi

case $option in
    1)
        [ "$BOOT_USB" = true ] || { echo "no boot device detected"; exit 1; }
        device="$BOOT_DEVICE"
        ON_BOOT=true
        ;;
    2)
        echo ""
        sudo lsblk -d -o NAME,SIZE,TYPE,TRAN | grep -v loop
        read -p "device (e.g. /dev/sdb): " device
        ON_BOOT=false
        ;;
    3)
        echo ""
        read -p "device (e.g. /dev/sdb): " device
        ON_BOOT=false
        ;;
    *)
        echo "invalid"
        exit 1
        ;;
esac

[ -b "$device" ] || { echo "$device not found"; exit 1; }

echo ""
echo "about to modify: $device"
if [ "$ON_BOOT" = true ]; then
    echo "will add a new partition to the boot USB, existing data stays"
else
    echo "will wipe $device and use the whole thing"
fi
echo ""
read -p "type YES to continue: " confirm
[ "$confirm" = "YES" ] || { echo "cancelled"; exit 0; }

echo ""
echo "setting up persistence..."

if [ "$ON_BOOT" = true ]; then
    # find free space, make partition there
    FREE=$(sudo parted "$device" unit B print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $3}' | sed 's/B//')
    if [ -n "$FREE" ] && [ "$FREE" -gt 4000000000 ]; then
        echo "using ${FREE} bytes of free space"
        sudo parted "$device" mkpart primary ext4 -4GB 100% 2>/dev/null || \
        sudo parted "$device" mkpart primary ext4 ${FREE}B 100%
    else
        echo "shrinking last partition to make room..."
        sudo parted "$device" resizepart 2 -4GB 2>/dev/null || true
        sudo parted "$device" mkpart primary ext4 -4GB 100%
    fi
    sleep 3
    part=$(lsblk -ln -o NAME "$device" | tail -1)
    partition="/dev/${part}"
else
    sudo parted -s "$device" mklabel gpt
    sudo parted -s "$device" mkpart primary ext4 0% 100%
    sleep 2
    partition="${device}1"
    [ -b "$partition" ] || partition="${device}p1"
fi

echo "formatting $partition..."
sudo mkfs.ext4 -F -L persistence "$partition"
sleep 1

# write the persistence config
# "/ union" means overlay the whole rootfs - packages, configs, everything
sudo mkdir -p /mnt/persistence
sudo mount "$partition" /mnt/persistence
echo "/ union" | sudo tee /mnt/persistence/persistence.conf
sudo umount /mnt/persistence

echo ""
echo "============================================="
echo "done! persistence partition: $partition"
echo "============================================="
echo ""
echo "reboot now and it should pick up automatically."
echo ""
read -p "reboot? (y/n): " rb
[ "$rb" = "y" ] && sudo reboot
PERSIST_EOF
chmod +x /usr/local/bin/setup-persistence

# ============================================================
# usb writer helper
# ============================================================
cat > /usr/local/bin/write-to-usb <<'USBEOF'
#!/bin/bash
echo "============================================="
echo "  TinyDebian USB Writer"
echo "============================================="
echo ""

[ "$EUID" -eq 0 ] || { echo "need sudo"; exit 1; }

echo "USB drives:"
lsblk -d -o NAME,SIZE,TYPE,TRAN,VENDOR,MODEL | grep usb
echo ""

read -p "target device (e.g. /dev/sdb): " device
[ -b "$device" ] || { echo "device not found"; exit 1; }

# don't let people accidentally nuke sda
echo "$device" | grep -q "sda$" && {
    echo "WARNING: $device looks like your main disk"
    read -p "type 'I AM SURE' to continue: " c
    [ "$c" = "I AM SURE" ] || { echo "cancelled"; exit 0; }
}

read -p "iso path: " iso
[ -f "$iso" ] || { echo "file not found"; exit 1; }

echo ""
echo "writing $iso -> $device"
read -p "type YES: " c
[ "$c" = "YES" ] || { echo "cancelled"; exit 0; }

echo ""
echo "writing... don't pull the USB"
dd if="$iso" of="$device" bs=4M status=progress oflag=sync
[ $? -eq 0 ] && echo "done. safe to remove." || echo "something went wrong"
USBEOF
chmod +x /usr/local/bin/write-to-usb

# ============================================================
# desktop shortcuts
# ============================================================
mkdir -p /home/live/Desktop

cat > /home/live/Desktop/setup-persistence.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Setup Persistence
Comment=Save your changes across reboots
Exec=xfce4-terminal -e "sudo /usr/local/bin/setup-persistence"
Icon=drive-harddisk
Terminal=false
Categories=System;Settings;
EOF
chmod +x /home/live/Desktop/setup-persistence.desktop

cat > /home/live/Desktop/gparted.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=GParted
Comment=Partition Editor
Exec=gparted-pkexec
Icon=gparted
Terminal=false
Categories=System;Administration;
EOF
chmod +x /home/live/Desktop/gparted.desktop

cat > /home/live/Desktop/gemini-setup.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Gemini AI Setup
Comment=Set up your Gemini API key
Exec=xfce4-terminal -e "bash -c 'echo \"=== Gemini Setup ===\"; echo \"\"; echo \"get a key at: https://aistudio.google.com/app/apikey\"; echo \"\"; read -p \"paste your key: \" key; echo \"export GEMINI_API_KEY=$key\" >> ~/.bashrc; echo \"\"; echo \"done. test with:  gemini hello\"; echo \"\"; read -p \"press enter...\"; exec bash'"
Icon=applications-science
Terminal=false
Categories=Development;Utility;
EOF
chmod +x /home/live/Desktop/gemini-setup.desktop

# ============================================================
# locales
# ============================================================
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "ar_EG.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# ============================================================
# enable services, fix perms, own the homedir
# ============================================================
systemctl enable NetworkManager
systemctl enable lightdm
# vmtoolsd runs as a systemd service — enable it so it starts on boot
# even if the autostart helper didn't catch it for some reason
systemctl enable vmtoolsd 2>/dev/null || true
chmod 755 /tmp
chmod 1777 /var/tmp
chown -R live:live /home/live

# ============================================================
# cleanup - strip out stuff we don't need to save space
# ============================================================
echo "cleaning up..."
apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb
rm -rf /tmp/* /var/tmp/* /var/cache/debconf/*
find /usr/share/doc -type f ! -name copyright -delete 2>/dev/null || true
find /usr/share/doc -type d -empty -delete 2>/dev/null || true
rm -rf /usr/share/man/* /usr/share/info/* 2>/dev/null || true
# keep english and arabic locales, nuke the rest
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'ar*' -exec rm -rf {} + 2>/dev/null || true

echo "chroot done"
CHROOT_EOF

chmod +x "$WORK_DIR/chroot/install.sh"

echo "[5/10] running install inside chroot (10-20 min)..."
chroot "$WORK_DIR/chroot" /install.sh || { echo "chroot install failed"; exit 1; }

# --------------- step 6: cleanup chroot ---------------
echo "[6/10] cleaning up..."
rm -f "$WORK_DIR/chroot/install.sh"
cleanup

# --------------- step 7: squashfs ---------------
echo "[7/10] making squashfs..."
rm -f "$WORK_DIR/iso/live/filesystem.squashfs"
mksquashfs "$WORK_DIR/chroot" "$WORK_DIR/iso/live/filesystem.squashfs" \
    -comp xz -Xbcj x86 -b 1M -e boot/

# --------------- step 8: kernel + initrd ---------------
echo "[8/10] copying kernel and initrd..."
KERNEL=$(ls "$WORK_DIR/chroot/boot"/vmlinuz-* 2>/dev/null | sort -V | tail -1)
INITRD=$(ls "$WORK_DIR/chroot/boot"/initrd.img-* 2>/dev/null | sort -V | tail -1)

if [ -z "$KERNEL" ] || [ -z "$INITRD" ]; then
    echo "kernel or initrd missing:"
    ls -la "$WORK_DIR/chroot/boot"
    exit 1
fi

cp "$KERNEL" "$WORK_DIR/iso/live/vmlinuz"
cp "$INITRD" "$WORK_DIR/iso/live/initrd"
echo "kernel: $(basename $KERNEL)"
echo "initrd: $(basename $INITRD)"

# --------------- step 9: bootloaders ---------------
echo "[9/10] setting up grub and isolinux..."
mkdir -p "$WORK_DIR/iso/boot/grub"

# grub config (EFI boot)
# persistence entries use "live-persistence=auto" so live-boot searches
# all partitions for a "persistence" label. that's what makes packages
# and everything else actually stick across reboots.
cat > "$WORK_DIR/iso/boot/grub/grub.cfg" <<'GRUBEOF'
set timeout=10
set default=0

insmod all_video
insmod gfxterm
insmod usb_keyboard
insmod usbms
terminal_output gfxterm

menuentry "TinyDebian Live (Persistence) - DEFAULT" {
    linux /live/vmlinuz boot=live components quiet splash persistence live-persistence=auto live-media-path=/live noeject
    initrd /live/initrd
}

menuentry "TinyDebian Live (Persistence - Safe Mode)" {
    linux /live/vmlinuz boot=live components persistence live-persistence=auto live-media-path=/live noeject rootdelay=10
    initrd /live/initrd
}

menuentry "TinyDebian Live (No Persistence)" {
    linux /live/vmlinuz boot=live components quiet splash live-media-path=/live noeject
    initrd /live/initrd
}

menuentry "TinyDebian Live (Failsafe)" {
    linux /live/vmlinuz boot=live components noapic noacpi nodma nomce nolapic nosmp vga=normal live-media-path=/live noeject rootdelay=10
    initrd /live/initrd
}

menuentry "TinyDebian Live (Show Boot Messages)" {
    linux /live/vmlinuz boot=live components persistence live-persistence=auto live-media-path=/live noeject
    initrd /live/initrd
}

menuentry "TinyDebian Live (Copy to RAM)" {
    linux /live/vmlinuz boot=live components toram quiet splash live-media-path=/live
    initrd /live/initrd
}
GRUBEOF

# efi image
dd if=/dev/zero of="$WORK_DIR/iso/boot/grub/efi.img" bs=1M count=10
mkfs.vfat "$WORK_DIR/iso/boot/grub/efi.img"
mmd -i "$WORK_DIR/iso/boot/grub/efi.img" ::/EFI
mmd -i "$WORK_DIR/iso/boot/grub/efi.img" ::/EFI/BOOT

if [ -f /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ]; then
    mcopy -i "$WORK_DIR/iso/boot/grub/efi.img" /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ::/EFI/BOOT/BOOTX64.EFI
elif [ -f /usr/lib/grub/x86_64-efi/grubx64.efi ]; then
    mcopy -i "$WORK_DIR/iso/boot/grub/efi.img" /usr/lib/grub/x86_64-efi/grubx64.efi ::/EFI/BOOT/BOOTX64.EFI
else
    echo "WARNING: no grub efi binary found, uefi boot won't work"
fi

# isolinux (BIOS boot)
mkdir -p "$WORK_DIR/iso/isolinux"
cp /usr/lib/ISOLINUX/isolinux.bin "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/ldlinux.c32  "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/libcom32.c32 "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/libutil.c32  "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/menu.c32     "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/vesamenu.c32 "$WORK_DIR/iso/isolinux/"

cat > "$WORK_DIR/iso/isolinux/isolinux.cfg" <<'ISOLEOF'
UI vesamenu.c32
TIMEOUT 100
PROMPT 0

MENU TITLE TinyDebian Live
MENU COLOR screen 37;40
MENU COLOR border 30;44
MENU COLOR title 1;36;44
MENU COLOR sel 7;37;40
MENU COLOR unsel 37;44
MENU COLOR help 37;40
MENU COLOR timeout 1;37;40
MENU COLOR timeout_msg 37;40

DEFAULT live

LABEL live
  MENU LABEL ^TinyDebian (Persistence) - DEFAULT
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live components quiet splash persistence live-persistence=auto live-media-path=/live noeject

LABEL safe
  MENU LABEL TinyDebian (Persistence ^Safe Mode)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live components persistence live-persistence=auto live-media-path=/live noeject rootdelay=10

LABEL nopersist
  MENU LABEL TinyDebian (^No Persistence)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live components quiet splash live-media-path=/live noeject

LABEL failsafe
  MENU LABEL TinyDebian (^Failsafe)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live components noapic noacpi nodma nomce nolapic nosmp live-media-path=/live noeject rootdelay=10

LABEL nosplash
  MENU LABEL TinyDebian (Show Boot ^Messages)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live components persistence live-persistence=auto live-media-path=/live noeject

LABEL toram
  MENU LABEL TinyDebian (Copy to ^RAM)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live components toram quiet splash live-media-path=/live
ISOLEOF

# --------------- step 10: build the iso ---------------
echo "[10/10] building iso..."

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "TinyDebian" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    -output "$ISO_OUTPUT" \
    "$WORK_DIR/iso" 2>&1

# if efi fails, fall back to bios-only
if [ $? -ne 0 ]; then
    echo "efi boot failed, making bios-only iso..."
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "TinyDebian" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -output "$ISO_OUTPUT" \
        "$WORK_DIR/iso"
fi

# --------------- done ---------------
echo ""
echo "========================================="
echo "  build complete"
echo "========================================="
echo "iso: $ISO_OUTPUT"
echo "size: $(du -h "$ISO_OUTPUT" | cut -f1)"
echo "squashfs: $(du -h "$WORK_DIR/iso/live/filesystem.squashfs" | cut -f1)"
echo ""
echo "--- write to usb ---"
echo "linux:  sudo dd if=$ISO_OUTPUT of=/dev/sdX bs=4M status=progress oflag=sync"
echo "windows: use rufus (rufus.ie) in DD image mode"
echo "macos:  sudo dd if=$ISO_OUTPUT of=/dev/diskX bs=4m"
echo ""
echo "--- after booting ---"
echo "1. desktop opens automatically (live/live)"
echo "2. click 'Setup Persistence' on desktop"
echo "3. pick option 1 (on boot USB) and say YES"
echo "4. reboot -> everything you install/change is saved now"
echo ""
echo "--- vmware copy/paste ---"
echo "just works out of the box. if it doesn't:"
echo "  - check /tmp/vmware-clipboard.log for what happened"
echo "  - try: sudo systemctl restart vmtoolsd"
echo "  - from terminal: echo 'hello' | xclip -selection clipboard"
echo ""
echo "keyboard: alt+shift toggles english/arabic"
echo "gemini: click 'Gemini AI Setup' on desktop to configure"
echo "========================================="
