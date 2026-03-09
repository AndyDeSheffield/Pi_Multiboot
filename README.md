# A Novel Multi-Boot Architecture for the Raspberry Pi
## Introduction
First a **disclaimer**. This project is very much alpha and was something to occupy me during the winter months. I wouldn't touch this at all unless you are fairly familiar with how the Raspbery pi boots. \
I wanted to create a multi-boot system that had the following properties:- 
-  boots **.img** files rather than physical partitions.
-  All images would use their own kernels and their own dtb structure(base,overlay,properties)
-  Images could be anywhere, on any disk or any partition
-  An images partition could contain images for multiple pi models
-  Posibility to extend the size of an image without hitting barriers due to a suceeding partition
-  Be able to use a (slightly modified) version of the Rpi-Imager tool to create the .img files from the official source repository

## Limitations
There are some limitations to what this system will boot 
-  The kernel of the image must include a uefi stub as this project uses the uefi bootloaders created by the [Pi Firmware Task Force](https://github.com/pftf)
-  64 bit images only. This is a little limiting for the pi3b
-  The system can have images for multiple devices but the single boot partition has to be device specific
-  Booting of some of the more exotic images like lineage will not work
-  Only very basic initramfs systems like the Ubuntu one which contains modules but no init script are supported
### Tested images
-  pi3b
   -  Raspberry Pi OS (64-bit)Trixie
   -  Raspberry PI OS Lite (64 bit)
   -  Ubuntu Server 24.04.4 LTS (64 bit)
-  pi4
   -  Raspberry Pi OS (64-bit)Trixie
   -  Raspberry PI OS Lite (64 bit)
   -  Ubuntu Server 25.10 (64 bit)
## Disk Structure 
The disk structure is the following :-
1. A per device **REALBOOT** partition. This can be on a master drive if you have all the same hardware type or on, for example, its own USB key or microSD with a common drive for other partitions if you want to boot images for the Pi3B and Pi4 on the same master disk \
It contains the UEFI bootloader and the **grub** binary and **grub.cfg** which the multiboot system relies upon
2. A single systemwide **System** partition. This contains the logic for the multiboot process
3. One or more Image partitions on one or more disks. This contains the os images. Note that some of the utilites provided assume just one such partition but it isnt a hard limitation

## How it works
The image below describes the flow of the boot process.
_add in link_ 
1. The Pi firmware loads the uefi firmware in the boot partition. Note that the (provided) config.txt file used here is minimal. \
The dtb properties and any overlays along with overlay properties in the original image boot sector config.txt are used to create a pre-merged dtb file for grub. However it is possible to set any global non-dtb properties here, although they will be set across all images.
2. the uefi firmware loads [**shellaa64.efi** by pbatard](https://github.com/pbatard/UEFI-Shell/release) renaomed as BOOTAA64.EFI. The purpose of this is just to introduce a delay and then request the uefi software to rescan for disk partitions in order to accomodate slow disks. It may not be necessary, in which case you can rename grub.efi toBOOTAA64.EFI and take this stage out.
3. grub loads its config file with the list of bootable images. When an image is selected it scans for the system partition and the images partition containing the selected image. It obtains the PARTUUID's and UUID's for the target partition and sytem partition, passing them as kernel parameters to the next stage.
4. The kernel is booted along with any minimal initramfs with the system preinit script specified as the INIT parameter
5. The preinit script parses the jernel command line to obtain the UUIDs of the target and system partitions. It then does a chroot to a simulated filebased initrd environment specifying the init script of that environment as next step
6. The init script (using busybox) loop mounts the root partition of the specified img file, mounts the relevant proc and sys mounts inside it and chroot's to /sbin/init inside the img loop mount
7. Second stage boot continues as per normal
## Tools
The following are provided:-
1. A shell script **multiboot-build.sh** which can create any combination of partitions for BOOT (called REALBOOT),SYSTEM, and IMAGES on a removable device. This also installs tar archives for the model specific boot partition and for the system partition 
2. A shell script  **makeimage.sh** to make a blank **.img** file of the desired size in MB
3. A shell script **attachimage.sh** to loop mount an image file (optionally mounting the partitions if there are any)
4. A modified  raspi-imager **raspi-loopimager** bundle for arm and intel that allows imaging to a loop mount
5. A tool for arm and intel **makedtb** which scans for and parses the config.txt in an image boot sector and creates merged dtb with all (main) overlays applied and properties (base and overlays) set

