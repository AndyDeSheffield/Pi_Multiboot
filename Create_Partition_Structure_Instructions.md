# Installation Instructions 

This set of instructions will create a 3 partition version of the architecture all on one disk. See the end of the document for details on how to create the various partitions on different disks
Be **very** careful to chose the right removable disk when running the install program.

### You will need

 - A functioning **Linux** operating system which has access to USB devices.
 For Windows users you cannot use a Hyper-V vm, nor WSL as these do not have USB access. The best solution is to install Ubuntu on a usb key and boot it into "Try Before You Install" mode.
 -  A USB key or a microSD card in a USB holder of at least 8GB capacity. If this is to be your main multiboot repository it is recommended  be at least 128GB, depending upon the number of OS that you wish to install.
 
 ### Installation Steps
 ##### Base USB Key
 1. Download the Pi_MultiBoot.tar.gz file from my repository and unpack it.
 
```  
cd ~
wget https://github.com/AndyDeSheffield/Pi_Multiboot/releases/download/Version_0.5_alpha/MultiBoot_Admin_os_v0.5.tar.gz
tar -xzf Pi_Multiboot_v0.5.tar.gz
```
 2. plug in the target USB key if you haven't already done so
 3. Identify your target USB key **carefully** using the multiboot-build.sh -l 
 command. Note that minimal help is available with multiboot-build.sh -h
 
 ```  
cd ~/Pi_Multiboot/create_structure
./multiboot-build.sh -h 
./multiboot-build.sh -l
```
 4. Identify the device that you wish to image here I'll assume it is **/dev/sdb** (replace as necessary) and that
 we are building for a pi4 (again replace as necessary run with -h to see models)
 Then for peace of mind I suggest that you do a dry run of the creation process using the -n option 
 Also we will stick to the default partition sizes

``` 
./multiboot-build.sh -n -t=/dev/sdb -m=pi4 -b -s -i 
```
 
 5. If you are happy then rerun for real. This needs sudo privileges
 
``` 
sudo ./multiboot-build.sh -t=/dev/sdb -m=pi4 -b -s -i 
```
 6. You should now have a 3 partition USB key. 
 ##### Admin OS Image
 For convenience I've provided a prepared admin os based on Raspi_Lite but with a minimal Xserver and console. There is a pre-installed grub entry that boots it. 
 If you want to install this (recommended) continue on.
 ###### Automated Installation
  1. Download the installation script and run it, replacing sdb with your newly installed disk identifier ( the -l options lists current disks for a safety check)
```
  cd ~
  wget https://github.com/AndyDeSheffield/Pi_Multiboot/releases/download/Version_0.5_alpha/install_multiboot_admin_os.sh
  ./install_multiboot_admin_os.sh -l 
  ./install_multiboot_admin_os.sh sdb
```
 ###### Manual Installation
 If for any reason the automated installation didn't work or if you prefer to know what's going on here are the manual Steps
 
  1. Mount the IMAGES partition of the key

``` 
sudo mkdir -p /mnt/realimages
sudo mount /dev/sdb3 /mnt/realimages
cd /mnt/realimages/staging/
```
 2. Fetch the admin tarball, unpack it and install the image directory (update the release directory and name as necessary)

```
 wget https://github.com/AndyDeSheffield/Pi_Multiboot/releases/download/Version_0.5_alpha/MultiBoot_Admin_os_v0.5.tar.gz
 tar -xzf MultiBoot_Admin_os_v0.5.tar.gz -C /mnt/realimages
 sync
```
 3. Unmount the partitions and optionally remove the mountpoints
```
cd ~
sudo unmount /mnt/realboot
sudo unmount /mnt/realimages
sudo rmdir /mnt/realboot
sudo rmdir /mnt/realimages

```
 ##### Testing
 Transfer the usb key to the target device and try to boot. If it is a microSD card you can optionally put it into the slot on the pi.
 **Note that the BOOT partition on this key must be the only one in the system.** 
 Also only one SYSTEM partition is allowed.You can have any number of IMAGES partitions
 
 ##### Split Disks
Notes on splitting the architecture over different disks. 
This quite simply comes down to repeating steps 2 to 6 of the BASE USB section of this  guide
but specifying less partitions at stages 4 and 5.
For example to just put the Boot partiton on a disk run 

``` 
sudo ./multiboot-build.sh -n -t=/dev/sdb -m=pi4 -b
sudo ./multiboot-build.sh -t=/dev/sdb -m=pi4 -b
```
Then for a second disk with the SYSTEM and IMAGES partitions
``` 
sudo ./multiboot-build.sh -n -t=/dev/sdb -m=pi4 -s -i
sudo ./multiboot-build.sh -t=/dev/sdb -m=pi4 --s -i
```
