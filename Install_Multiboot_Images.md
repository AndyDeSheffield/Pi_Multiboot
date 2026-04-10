

# How to Install Images
##Introduction
This guide assumes the use of the provided Multiboot_Admin environment to install additional images, although the same approach is used to install images using an external Linux os.
This os should auto-login with two console screens but in a gui environment. For info **user=pi, password=pi**
## 1) Install or update the Multiboot Toolchain
- If using the Multiboot_Admin os then this toolchain comes pre-installed at /home/pi/Pi_Multiboot. However you should make sure that it is up to date by running 
 ```  
cd ~
./update_imager.sh
```
- If using an externel os you can fetch and then run the same script
```  
cd ~
wget https://raw.githubusercontent.com/AndyDeSheffield/Pi_Multiboot/refs/heads/main/tools/update_imager.sh
sudo chmod +x update_imager.sh
./update_imager.sh
```
## 2) Mount the images partition which will receive your new os
- When using the Multiboot_Admin os this is most likely your current images partition. In this case it can be mounted using the script in the Pi_Multiboot/tools directory
``` 
Pi_Multiboot/tools/mountdrives.sh
```
your target partition will be /mnt/realimages

- Otherwise you will likely be installing to an external usb key partition (example /dev/sdb3) so
```
mkdir -p ~/realimages
sudo mount /dev/sdb3 ~/realimages
```
your target partition is of course ~/realimages

## 3) Run the image creation tool 
- First check the help
- Note that after each action the imaging tool gives the option to continue or abort (which backs out previous steps)
```
cd ~/Pi_Multiboot/create_images
./install_image.sh -h

Usage: ./install_image.sh -r=<root_mount> -n=<name_of_image> -m=<pi_model> -s=<size> [-e] [-h]
  -r=<root_mount>    Root of mounted image disk (e.g. -r=/mnt/realimages)  
  -n=<name>          Name of image (letters, numbers, '-', '_')  
  -m=<pi_model>      Pi model (e.g. pi3b,pi3b+,pi4, pi5)  
  -s=<size>          Image size (e.g. 10G)  
  -e                 Expand root filesystem (only if exactly 2 partitions exist)  
  -h                 Show this help  
  Note that the script needs to be run with sudo  
```
- 
- Run the tool as sudo with the appropriate parameters
```
sudo ./install_image.sh -r=/mnt/realimages -n=My_New_OS -m=pi4 -s=10G -e
```
1) Step 1 creates the blank .img file on the root Mount  
```
Step 1: Creating target directory and blank image...
Created image: /mnt/realimages/My_New_OS_pi4/My_New_OS_pi4.img (size 10G)

Step 1 completed. Continue (c) or Abort (a)? [c/a]:
```
2) Step 2 runs a modified version of the raspi-imager that accepts loop mounts as targets
```
Step 2: Loop-mounting image and running Raspberry Pi Imager...
Loop device: /dev/loop2
Launching Raspberry Pi Imager...
Refreshing loop partitions...
Reattached loop device: /dev/loop2
```
Follow the usual imaging process selecting the loop device attached to your image as the target  
```
Step 2 completed. Continue (c) or Abort (a)? [c/a]:
```
3) Step 3 creates a dtb file with all the overlays and properties  specified in the config.txt
 of the target boot partition merged in. It copies that dtb, along with the target kernel
 and any initramfs into a directory /target_name on the root mount.
 A suitable Grub entry file is also created
```
Continuing...
Step 3: Extracting DTB and kernel...
Handling uefi fixes. Installing cpufix.dtbo and uefi_fixes.txt
Model: pi4 (index 5)
Boot directory: ./bootpart
Will output to : /mnt/realimages/My_New_OS_pi4/My_New_OS_pi4{.dtb,.kernel,.cmdline,.initrd}
Any kernel, cmdline and initrd files will be copied (-x specified.)


UNTREATED CONFIG LINES stored in  /mnt/realimages/My_New_OS_pi4/untreated_config.txt
uefi_fixes.txt found and will be processed after config.txt
COPYING FULL Config.txt ./bootpart/config.txt to /mnt/realimages/My_New_OS_pi4/config.txt
COPYING DEFAULT KERNEL ./bootpart/kernel8.img to /mnt/realimages/My_New_OS_pi4/My_New_OS_pi4.kernel
COPYING DEFAULT INITRAMFS ./bootpart/initramfs8 to /mnt/realimages/My_New_OS_pi4/My_New_OS_pi4.initrd
COPYING COMMAND LINE ./bootpart/cmdline.txt to /mnt/realimages/My_New_OS_pi4/My_New_OS_pi4.cmdline
SET_BASE_PROPERTY (group 0): audio=on
LOAD_OVERLAY (group 1): ./bootpart/overlays/vc4-kms-v3d-pi4.dtbo
APPLY_OVERLAY (group 1): ./bootpart/overlays/vc4-kms-v3d-pi4.dtbo
LOAD_OVERLAY (group 2): ./bootpart/overlays/miniuart-bt.dtbo
APPLY_OVERLAY (group 2): ./bootpart/overlays/miniuart-bt.dtbo
LOAD_OVERLAY (group 3): ./bootpart/overlays/cpufix.dtbo
APPLY_OVERLAY (group 3): ./bootpart/overlays/cpufix.dtbo
LOAD_OVERLAY (group 4): ./bootpart/overlays/upstream-pi4.dtbo
APPLY_OVERLAY (group 4): ./bootpart/overlays/upstream-pi4.dtbo
COPYING MERGED DTB to /mnt/realimages/My_New_OS_pi4/My_New_OS_pi4.dtb
Files sucessfully created
Step 3.7: Optional expansion...
Expanding root filesystem...
Model: Loopback device (loopback)
Disk /dev/loop2: 10.7GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system  Flags
 1      8389kB  545MB   537MB   primary  fat32        lba
 2      545MB   6451MB  5906MB  primary  ext4

e2fsck 1.47.2 (1-Jan-2025)
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
rootfs: 138407/360448 files (0.1% non-contiguous), 1269154/1441792 blocks
resize2fs 1.47.2 (1-Jan-2025)
Resizing the filesystem on /dev/loop2p2 to 2488320 (4k) blocks.
The filesystem on /dev/loop2p2 is now 2488320 (4k) blocks long.

Expansion complete.
[cleanup] Forcing release of ./bootpart...
Generating GRUB entry: /mnt/realimages/My_New_OS_pi4/Grub_My_New_OS_pi4.cfg
GRUB entry written to: Grub_My_New_OS_pi4.cfg
Image creation completed successfully.
Directory: /mnt/realimages/My_New_OS_pi4
total 6332204
-rwxr-xr-x 1 root root        1247 Dec  4 14:40 config.txt
-rw-r--r-- 1 root root        1009 Apr 10 14:46 Grub_My_New_OS_pi4.cfg
-rwxr-xr-x 1 root root         183 Apr 10  2026 My_New_OS_pi4.cmdline
-rw-r--r-- 1 root root       81495 Apr 10 14:46 My_New_OS_pi4.dtb
-rw-r--r-- 1 root root 10737418240 Apr 10 14:46 My_New_OS_pi4.img
-rwxr-xr-x 1 root root    22480912 Dec  4 14:49 My_New_OS_pi4.initrd
-rwxr-xr-x 1 root root     9678820 Dec  4 14:39 My_New_OS_pi4.kernel
-rw-r--r-- 1 root root         128 Apr 10 14:46 untreated_config.txt
``
