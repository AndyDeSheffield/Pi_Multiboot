sudo mkdir -p /mnt/realboot
sudo mkdir -p /mnt/realsystem
sudo mkdir -p /mnt/realimages

model="$(tr -d '\0' </proc/device-tree/model)"

if echo "$model" | grep -q "Raspberry Pi 3"; then
  sudo mount -L BOOTPI3 /mnt/realboot
else
  sudo mount -L BOOTPI4 /mnt/realboot
fi

sudo mount -L SYSTEM /mnt/realsystem
sudo mount -L IMAGES /mnt/realimages
sudo mount -t cifs //192.168.1.200/public /mnt/wdmycloud -o guest
