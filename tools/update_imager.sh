
#!/usr/bin/env bash
echo "Fetching latest version of Pi_Multiboot"
if ! wget -q --show-progress "https://github.com/AndyDeSheffield/Pi_Multiboot/releases/download/latest/Pi_Multiboot.tar.gz"; then
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
echo "installing latest version"
tar -xzf Pi_Multiboot.tar.gz
echo "removing tar file Pi_Multiboot.tar.gz"
rm Pi_Multiboot.tar.gz
VERSION=$(cat Pi_Multiboot/version)
echo "installed version ${VERSION}"
