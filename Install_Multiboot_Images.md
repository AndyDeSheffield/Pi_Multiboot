# How to Install Images
## Introduction
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
<div>
-  Select Pi model <br>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.1.jpg?raw=true" style="margin: 10px;  width:50%; height:50%"/> <br>
-  Select Operating System <br>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.2.jpg?raw=true" style="margin: 10px;  width:50%; height:50%"/> <br>
	Select Target loop --- <b>Be careful NOT to select the SSD or Hard drive itself!</b> <br>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.3.jpg?raw=true" style="margin: 10px;  width:50%; height:50%"/> <br>
-  Configure if desired <br>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.4.jpg?raw=true" style=" margin: 10px; width:45%; height:45%"/>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.5.jpg?raw=true" style=" margin: 10px; width:45%; height:45%"/>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.6.jpg?raw=true" style=" margin: 10px; width:45%; height:45%"/>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.7.jpg?raw=true" style=" margin: 10px; width:45%; height:45%"/>
    <img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.8.jpg?raw=true" style=" margin: 10px; width:45%; height:45%"/> <br>
-  Write Image <br>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.9.jpg?raw=true" style=" margin: 10px; width:50%; height:50%"/> <br>
- Confirm Write <br>
 	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.10.jpg?raw=true" style=" margin: 10px; width:50%; height:50%"/> <br>
- Writing <br>
 	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.11.jpg?raw=true" style="margin: 10px; width:50%; height:50%"/> <br>
- Finish <br>
 	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/pi_imager.12.jpg?raw=true" style=" margin: 10px;width:50%; height:50%"/> <br>
</div>

```
Step 2 completed. Continue (c) or Abort (a)? [c/a]:
```
3) Step 3 creates a dtb file with all the overlays and properties  specified in the config.txt
 of the target boot partition merged in.
   -  It copies that dtb, along with the target kernel
      and any initramfs into a directory /target_name on the root mount.
   -  A suitable Grub entry file is also created
   -  The kernel cmdline used in the official image is extracted for reference. Use the "extras" variable in the grub config
      to add any desired values.
   -  The config.txt from the original boot partition is extracted for reference and a file "untreated_config.txt" is created showing
      lines that it has not been possible to process.
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
```
## 4) Insert the contents of the suggested Grub file int grub.cfg
- If using the Multiboot_Admin os and you have mounted the target partitionusing mountdrives.sh you are already in a position to do this.
```
sudo cp /mnt/realboot/efi/boot/grub.cfg /mnt/realboot/efi/boot/grub.cfg.bak
sudo cat /mnt/realimages/My_New_OS_pi4/Grub_My_New_OS_pi4.cfg | sudo tee -a /mnt/realboot/efi/boot/grub.cfg
```
Otherwise you have to insert the device that you will be using and mount it
the grub.cfg file that needs updating will be  <Mount>/efi/boot/grub.cfg
## 5) Unmount the partitions cleanly
With the Multiboot_Admin os use
```
~/Pi_Multiboot/tools/unmountdrives.sh
```
## 6) Test
<div>
- Grub entry <br>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/bootimg.jpg?raw=true" style="margin: 10px; width:70%; height:70%"/> <br>
- After Boot <br>
	<img src="https://github.com/AndyDeSheffield/Pi_Multiboot/blob/main/documentation_images/mainscreen.jpg?raw=true" style="margin: 10px; width:70%; height:70%"/> <br>

</div>

- Note that
    - First boot of many OSes can take a long time
	- There will be some errors in the startup mainly due to upower (not sure what this is)
	- There is often an unexpected reboot after the very first boot. This may be the Raspbian resize functionality kicking in, I'm not sure.

##  Conclusion
All the 64 bit Raspian images and the 64 bit Ubuntu images that I've tested booted using this technique. All 4 processors are present and there is working sound but that's all that I've tested.
#### Footnote
Using some slight variations I've also managed to boot :-
- **LibreELECT** (v21.3 and only for the pi4 currently, due to lack of pi5 hardware and LibreELECT for the pi3 being 32 bit)
    - Use the same process as above to create the image
    - This then requires a small overlay initramfs (to include a custom "platform_init" file that loop mounts the LibreELECT image and also a custom Grub entry. [LibreELECT files here](https://github.com/AndyDeSheffield/Pi_Multiboot/releases/download/Version_0.5_alpha/LibreELECT.zip)
	- Unzip the archive into the same directory as that of the LibreELECT img file
	- platform_init is included for info only. It isn't needed
	- If the version of the LibreELECT image changes on the raspi-imager you will have to update the grub entry to reference the new boot=UUID and disk=UUID entries in the grub "rootopts" variable.
- **Fedora** (Fedora-Workstation-Disk-43-1.6.aarch64.raw.xz) 
     - [From the official site] ( https://fedoraproject.org/workstation/download/)
	 - This also needs a specific grub entry and initramfs overlay. 
	 - The build process is much more manual. I'll provide details if anyone is interested
- I'm looking to see if I can do anything with **Lineage** but it would need quite a lot of detective work