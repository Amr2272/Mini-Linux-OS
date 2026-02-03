# TinyDebian Live - Mini Linux OS

A lightweight, persistent live Linux distribution built on Debian 12 Bookworm with XFCE desktop, Firefox, audio support, VMware clipboard integration, and Google Gemini CLI.

## Features

- **Minimal XFCE Desktop** - Fast, responsive, and resource-efficient GUI
- **Persistence** - Changes are saved across reboots to an ext4 partition
- **Network-Ready** - NetworkManager, WiFi firmware (iwlwifi, realtek, atheros), and all wireless tools
- **Audio Support** - PulseAudio, ALSA, pavucontrol for full audio experience
- **VMware Tools** - Full clipboard integration (copy/paste between host and VM)
- **Development Tools** - Node.js 22, Git, curl, wget, nano, vim-tiny, htop
- **Google Gemini CLI** - AI assistant integrated via `@google/gemini-cli`
- **Partition Tools** - GParted, parted, dosfstools, ntfs-3g, exfat support
- **Dual Boot** - BIOS (isolinux) and UEFI (GRUB) boot support
- **Hybrid ISO** - Works as both disc and USB stick (dd-able)
- **Auto-Login** - LightDM autologins as `live` user
- **Keyboard Setup** - English + Arabic, toggle with Alt+Shift

## Prerequisites

- **Host OS**: Debian 12 Bookworm or Ubuntu 22.04+ (Debian-based)
- **Architecture**: 64-bit x86 (amd64)
- **Disk Space**: At least 15 GB free in `$HOME`
- **Privileges**: Must run as root or with `sudo`
- **Internet**: Required for downloading packages

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Amr2272/Mini-Linux-OS.git
cd Mini-Linux-OS
chmod +x scripts/build-tinydebian.sh
```

### 2. Build the ISO

```bash
sudo ./scripts/build-tinydebian.sh
```

The build will take 10-30 minutes depending on your internet speed. It will:

1. Install host build tools (debootstrap, squashfs-tools, xorriso, etc.)
2. Bootstrap a minimal Debian Bookworm rootfs
3. Install kernel, XFCE, Firefox, audio, VMware tools, Node.js, Gemini CLI
4. Create persistence partition setup utilities
5. Compress to squashfs
6. Build a hybrid BIOS/UEFI ISO

Output: `$HOME/tiny-debian-build/TinyDebian-amd64.iso`

### 3. Write to USB

From **Linux**:

```bash
sudo dd if=$HOME/tiny-debian-build/TinyDebian-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with your actual USB device (NOT a partition like `/dev/sdX1`).

Or use the built-in helper inside the live system:

```bash
sudo write-to-usb
```

From **Windows**: Use [Rufus](https://rufus.ie) in "DD Image" mode.

From **macOS**:

```bash
sudo dd if=$HOME/tiny-debian-build/TinyDebian-amd64.iso of=/dev/diskX bs=4m
```

### 4. Boot and Enable Persistence

1. Boot from the USB (press F12/ESC at startup to choose boot device).
2. GRUB or isolinux boot menu appears; select default option.
3. XFCE desktop loads, user `live` auto-logs in (password: `live`).
4. **Double-click** `Setup Persistence` on the desktop.
5. Choose option **1** (use boot USB) and confirm with **YES**.
6. Reboot → all your installed packages and changes are now saved.

## Default Credentials

- **User**: `live`
- **Password**: `live`
- **Sudo**: No password required

## Included Tools & Applications

### System
- Linux kernel (amd64)
- live-boot, live-config, live-tools
- NetworkManager, wireless-tools, wpa_supplicant
- PulseAudio, ALSA, pavucontrol

### Desktop
- XFCE4, Xfce4-terminal
- Firefox ESR
- Thunar (file manager)
- Mousepad (text editor)
- GParted, Synaptic package manager
- File Roller (archive manager)

### Development
- Node.js 22 (from NodeSource)
- Google Gemini CLI
- Git, curl, wget
- nano, vim-tiny
- Python, grep, find, and standard Unix tools

### VMware
- open-vm-tools, open-vm-tools-desktop
- xclip, xsel (terminal clipboard)
- Auto-starting vmtoolsd clipboard daemon

## Keyboard Layout

- **Default**: English (US)
- **Toggle to Arabic**: Alt+Shift
- **Back to English**: Alt+Shift

Configured in `/etc/default/keyboard` and XFCE settings.

## VMware Clipboard

Copy/paste between your Windows/Mac host and the VM:

1. Just works automatically on VM startup.
2. Check `/tmp/vmware-clipboard.log` if it doesn't work.
3. Restart if needed: `sudo systemctl restart vmtoolsd`
4. From terminal: `echo 'text' | xclip -selection clipboard`

## Persistence Setup

After the first boot, run **Setup Persistence** (desktop icon or `sudo setup-persistence`):

- **Option 1**: Create persistence partition on the boot USB (recommended).
- **Option 2**: Use a different USB drive.
- **Option 3**: Manual device selection.

Once set up, live-boot automatically mounts the persistence partition on every boot and overlays it on the rootfs.

## Customization

### Rebuild with Custom Packages

Edit the `CHROOT_EOF` section in `build-tinydebian.sh` before running the build:

```bash
apt-get install -y <your-packages-here>
```

### Modify Desktop Settings

All user settings are in `/home/live/.config/`. You can bake in custom XFCE configs, Firefox profiles, etc. before the ISO is created.

### Change Boot Timeout

Edit `GRUBEOF` or `ISOLEOF` sections to adjust `TIMEOUT` (in deciseconds or 1/10ths of a second).

## File Structure

```
$HOME/tiny-debian-build/
├── chroot/              # Root filesystem (cleaned after ISO is made)
├── iso/
│   ├── live/
│   │   ├── vmlinuz      # Kernel
│   │   ├── initrd       # Initramfs
│   │   └── filesystem.squashfs  # Compressed rootfs
│   ├── boot/grub/       # GRUB config + EFI image
│   └── isolinux/        # BIOS boot files
└── TinyDebian-amd64.iso # Final ISO (hybrid BIOS/UEFI)
```

## Troubleshooting

### Build Fails at Chroot Step

- Check your internet connection.
- Ensure you have at least 15 GB free: `df -h $HOME`
- Try again with `sudo ./scripts/build-tinydebian.sh`

### USB Boot Fails

- Verify you wrote the ISO correctly: `sudo dd if=TinyDebian-amd64.iso of=/dev/sdX ...`
- Try different boot menu key (F12, ESC, F2, DEL) during startup.
- Check BIOS is set to **Legacy + UEFI** or try one at a time.

### Persistence Not Saving

1. Rerun `setup-persistence` inside the live system.
2. Check `/tmp/vmware-clipboard.log` for boot messages.
3. Ensure partition is labeled `persistence`: `sudo e2label /dev/sdX1 persistence`

### Keyboard Layout Stuck

Toggle: **Alt+Shift**

Or from terminal:

```bash
setxkbmap us      # English
setxkbmap ara     # Arabic
setxkbmap us,ara -option grp:alt_shift_toggle  # Both with toggle
```

### VMware Clipboard Not Working

1. Check if running in VMware: `cat /sys/class/dmi/id/product_name`
2. Check logs: `cat /tmp/vmware-clipboard.log`
3. Restart service: `sudo systemctl restart vmtoolsd`
4. Test from terminal:

```bash
echo 'test' | xclip -selection clipboard
```

## Performance Tips

- **Copy to RAM**: Boot with `toram` option from GRUB for fastest performance (uses ~2 GB RAM).
- **Disable Splash**: Choose "Show Boot Messages" to see what's loading.
- **Safe Mode**: Choose "Safe Mode" if desktop fails to start.

## License

MIT License - See LICENSE file.

## Building on Other Systems

This script is optimized for Debian 12. On Ubuntu 22.04+, you may need to:

1. Install `debootstrap`: `sudo apt-get install debootstrap`
2. Install `live-boot` tools: `sudo apt-get install live-boot live-config`

The script uses Debian repos, so Ubuntu should work fine, but the resulting ISO will be Debian-based.

## Contributing

Feel free to fork, submit issues, or contribute improvements!

---

**Made with ❤️ by a Linux enthusiast**
