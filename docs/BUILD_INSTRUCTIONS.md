# TinyDebian Build Instructions

## Full Build Script

The complete TinyDebian build script is available in `scripts/build-tinydebian.sh`. Due to its size (>1000 lines), it should be added to the repository via the following methods:

### Option 1: Clone and Run (Recommended)

```bash
git clone https://github.com/Amr2272/Mini-Linux-OS.git
cd Mini-Linux-OS
chmod +x scripts/build-tinydebian.sh
sudo ./scripts/build-tinydebian.sh
```

### Option 2: Download Script Directly

```bash
wget https://raw.githubusercontent.com/Amr2272/Mini-Linux-OS/main/scripts/build-tinydebian.sh
chmod +x build-tinydebian.sh
sudo ./build-tinydebian.sh
```

## System Requirements

- **OS**: Debian 12 Bookworm or Ubuntu 22.04+ (Debian-based)
- **Architecture**: 64-bit x86 (amd64)
- **RAM**: At least 2 GB
- **Disk Space**: 15+ GB free
- **Internet**: Required for package downloads

## Build Process Overview

The script performs these steps automatically:

1. **Setup**: Creates build directory structure, validates system resources
2. **Tools**: Installs host build tools (debootstrap, squashfs-tools, xorriso, grub, isolinux)
3. **Bootstrap**: Downloads and extracts minimal Debian Bookworm rootfs
4. **Base Config**: Sets hostname, APT repositories, locales
5. **Packages**: Installs kernel, XFCE, Firefox, audio, VMware tools, Node.js 22, Gemini CLI
6. **Scripts**: Bakes in persistence setup wizard, USB writer, resolution fixer, VMware clipboard helper
7. **Squashfs**: Compresses rootfs with XZ compression
8. **ISO Build**: Creates hybrid BIOS/UEFI bootable ISO

## Expected Output

```
$HOME/tiny-debian-build/TinyDebian-amd64.iso
```

File size: Typically 1.2-1.5 GB (compressed with XZ)

## Build Time

- **Fast connection (>50 Mbps)**: 10-15 minutes
- **Medium connection (10-50 Mbps)**: 15-30 minutes  
- **Slow connection (<10 Mbps)**: 30-60+ minutes

Most time is spent downloading and installing packages.

## Next Steps After Build

1. Write ISO to USB: `sudo dd if=$HOME/tiny-debian-build/TinyDebian-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync`
2. Boot from USB (F12/ESC at startup)
3. Login as `live` / `live`
4. Click "Setup Persistence" on desktop
5. Reboot → changes are now saved

See [README.md](../README.md) for complete documentation.
