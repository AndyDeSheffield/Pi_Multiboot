LICENSE

This project contains original work by the author as well as several third-party components.
All components are licensed under their respective licenses as detailed below.

---

# 1. License for Original Code (MIT License)

All files not explicitly listed under third-party sections are licensed under the MIT License:

MIT License

Copyright (c) 2024 <Your Name>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this ftware and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CSONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

# 2. GPL-2.0+ Components

These components are licensed under the GNU Ceneral Public License version 2 or later.

Statically linked files:
- `merge-dtb` (and source files)
- `libfdt` (from DTC/U-Boot)

---

# 3. Apache-2.0 Components

Files:
- `raspi-loopimager` (modified from [Raspberry Pi Imager](https://github.com/raspberrypi/rpi-imager))

---

# 4. BSD-2-Clause-Patent Components (EDK2/UEFI)

UEFI Shell and other EDK2-derived binaries. (acknowledgements to [the Pi Firmware Task Force](https://github.com/pftf))

Renamed files:

- shell.efi renamed to BOOTAA64.EFI` (acknowledgements to [Pbatard](https://github.com/pbatard/UEFI-Shell/tree/main))
 

---

# 5. GRUB-3.0+ Components (GRUB EFI)

Files:
- `grubaa64.efi` 

---

# 6. Qt Installer Framework (QtIFW)

Used only as a packaging tool:
- `Raspberry_Pi_Imager-arm64.AppImage`
- `Raspberry_Pi_Imager-armx64.AppImage`

QtIFW is GPL-3.0 licensed.

---

# 7. Summary of File-to-License Mapping

All original code: MIT
merge-dtb: GPL-2.0+
libfdt: GPL-2.0+
Raspi-loopimager: Apache-2.0
BOOTAA64.EFI: BSD-2-Clause-Patent
grubaa64.efi: GPL-3.0+
QtIFW: GPL-3.0

---
END OF LICENSE
