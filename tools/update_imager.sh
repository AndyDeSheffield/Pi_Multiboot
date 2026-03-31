#!/usr/bin/env bash
VERSION=0.5
STATUS=alpha
echo "Fetching version Pi_Multiboot_v${VERSION}"
if ! wget -q --show-progress "https://github.com/AndyDeSheffield/Pi_Multiboot/releases/download/Version_${VERSION}_${STATUS}/Pi_Multiboot_v${VERSION}.tar.gz"; then
    echo "Download failed"
    exit 1
fi

if [ -d "Pi_Multiboot" ]; then
    if [ -d "Pi_Multiboot.old" ]; then
        sudo rm -r Pi_Multiboot.old
    fi

    echo "Moving Pi_Multiboot to Pi_Multiboot.old"
    sudo mv Pi_Multiboot Pi_Multiboot.old
fi
echo "installing new version (v${VERSION})"
tar -xzf Pi_Multiboot_v${VERSION}.tar.gz
echo "removing tar file Pi_Multiboot_v${VERSION}.tar.gz"
rm Pi_Multiboot_v${VERSION}.tar.gz
echo "Update complete"
