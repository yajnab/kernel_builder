## DYANK ArkOS Kernel Builder

### Overview

This project contains a helper script, `kernel_arkos.sh`, to build and package a custom ArkOS kernel using the Linaro AArch64 GCC toolchain.  
It is styled similarly to the Raspberry Pi `rpi4b.sh` builder, but targets ArkOS devices (for example RG351 family, RGB10, RK2020).

The script:

- Builds the kernel and DTBs from `arkos_kernel/`
- Installs kernel modules into `Arkbuild/`
- Prepares `uInitrd` inside `Arkbuild/boot/`
- Never touches or mounts an SD card; you manually copy the contents of `Arkbuild/` to your image / SD later.

---

### Requirements

- Linux host (x86_64 recommended)
- Linaro toolchain installed at:

```text
$HOME/toolchains/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu
```

- Directories in repo root:
  - `arkos_kernel/` – ArkOS kernel source tree
  - `Arkbuild/` – Output tree for kernel, modules, and initrd (created automatically)

- Basic build tools:
  - `make`
  - `u-boot-tools` (for `mkimage`; installed automatically if missing)
  - `qemu-user-static` (`/usr/bin/qemu-aarch64-static`)

---

### Environment Variables

Before running the script, you must set:

- **`UNIT`** – Target device name (for example `rg351p`, `rg351mp`, `rgb10`, `rk2020`, `g350`, `a10mini`)
- **`CHIPSET`** – SoC family (for example `rk3326`)

Examples:

```bash
export UNIT=rg351p
export CHIPSET=rk3326
```

If these are not set, the script will exit with a clear error.

---

### Kernel Source Selection

Inside `kernel_arkos.sh`:

- For `UNIT=rgb10` or `UNIT=rk2020`:
  - Uses `odroidgoA-4.4.y` tree and `odroidgoa_tweaked_defconfig`
  - Chooses the appropriate Odroid Go 2 DTB based on `UNIT`
- For all other units:
  - Uses `arkos_kernel/` directory in the repo root
  - Defconfig: `rg351p_tweaked_defconfig`
  - DTB path: `arch/arm64/boot/dts/rockchip/${CHIPSET}-${UNIT}-linux.dtb`

---

### What the Script Does

`kernel_arkos.sh` performs the following high‑level steps:

1. **Toolchain & environment setup**
   - Exports `PATH` to include the Linaro toolchain bin directory
   - Sets `ARCH=arm64` and `CROSS_COMPILE=aarch64-linux-gnu-`
   - Ensures required tools (`make`) and environment (`UNIT`, `CHIPSET`) exist

2. **Kernel configuration & build**
   - Optionally cleans the kernel tree (`mrproper`)
   - Runs the appropriate `defconfig` for the chosen device
   - Builds:
     - `Image`
     - Device trees (`dtbs`)
     - Kernel modules (`modules`)

3. **Module installation**
   - Installs kernel modules into `Arkbuild/lib/modules` via `INSTALL_MOD_PATH=Arkbuild`

4. **Packaging outputs into `Arkbuild/`**
   - Copies:
     - `.config` → `Arkbuild/boot/config-<kernel_version>`
     - `Image` → `Arkbuild/boot/`
     - DTB → `Arkbuild/boot/`
   - For certain units (`rg351mp`, `g350`, `a10mini`), also copies the `*-uboot.dtb` from `/tmp`

5. **Initramfs and `uInitrd` creation**
   - Uses `qemu-aarch64-static` in a chroot to run `depmod` and `update-initramfs`
   - Copies `initrd.img-*` to `Arkbuild/boot/initrd.img`
   - Uses `mkimage` to create `Arkbuild/boot/uInitrd`
   - Removes the temporary initrd

All artifacts are left inside `Arkbuild/`; you are responsible for copying them into your ArkOS image or SD card as needed.

---

### Usage

From the repository root:

```bash
# 1. Set target device and chipset
export UNIT=rg351p
export CHIPSET=rk3326

# 2. Ensure toolchain exists at:
#    $HOME/toolchains/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu
#    and kernel sources are in ./arkos_kernel

# 3. Run the builder
chmod +x kernel_arkos.sh
./kernel_arkos.sh
```

On success you’ll find:

- Kernel image and DTBs in `Arkbuild/boot/`
- Kernel modules in `Arkbuild/lib/modules/`
- `uInitrd` in `Arkbuild/boot/uInitrd`

You can then copy these into your ArkOS image or SD card as needed.

---

### Notes

- The script is designed **not** to mount or manipulate SD cards directly.
- If you change the toolchain location or kernel source directory, update the corresponding `readonly` variables at the top of `kernel_arkos.sh`.
- For RGB10 / RK2020, ensure the `odroidgoA-4.4.y` tree is available as expected by the script.

