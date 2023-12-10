# Modify Ufiber UF-Instant

This repo will contains modified RootFS and files used to convert UF-INSTANT SFP GPON stick from *Vendor Lock-in on UFiber products* to an open solution
that can interact with 3rd party OLT. 
Please note that on the market there are ready OOB (out-of-the-box) alternatives, you can take a lot at [Anime4000](https://github.com/Anime4000/RTL960x/) repo with all other information and compatible sticks. 
GUI on the modded firmware was made by Anime4000 :)

# All mods are just for fun, I am absolutely not responsible if your stick will die after the procedure :)


# Original Firmwares from Ubiquiti 

All files were extracted from OLT original firmware. *rootfs* files can be extracted with *unsquashfs* (parts of squashfs-tools)

# Partition Layout

MTD layout of UF-INSTANT is a little bit different from other Realtek Stick:

```
# cat /proc/mtd
dev:    size   erasesize  name
mtd0: 00040000 00001000 "boot"
mtd1: 00002000 00001000 "env"
mtd2: 00002000 00001000 "env2"
mtd3: 0003c000 00001000 "config"
mtd4: 00300000 00001000 "k0"
mtd5: 004b0000 00001000 "r0"
mtd6: 00300000 00001000 "k1"
mtd7: 004b0000 00001000 "r1"
mtd8: 00010000 00001000 "hw"
mtd9: 00010000 00001000 "sec"
mtd10: 00001000 00001000 "Partition_010"
mtd11: 00001000 00001000 "Partition_011"
mtd12: 00300000 00001000 "linux"
mtd13: 004b0000 00001000 "rootfs"
```

| Device | Size | Description |  
| ------ | ---- | ----------- |
| mtd0 | 256KB | U-Boot |
| mtd1 | 32KB | U-Boot Configuration 1 |
| mtd2 | 32KB | U-Boot Configuration 2 |
| mtd3 | 240KB | `/var/config` mount point where all stick configurations are saved |
| mtd4 | 3MB | kernel0, for the first image. |
| mtd5 | 4.8MB | rootfs0, for the first image. |
| mtd6 | 3MB | kernel1, for the second image.  |
| mtd7 | 4.8MB | rootfs2, for the second image.  |
| mtd8 | 64KB | Europa Driver (laser controller) calibration data; **pay attention**: unique per stick! |
| mtd9 | 64KB | Original UF-INSTANT firmware to write parameters, ignored by modified firmware |
| mtd10 | - | overlay partition |
| mtd11 | - | overlay partition |
| mtd12 | - | overlay partition |
| mtd13 | - | overlay partition |

To boot the first Image (mtd4 + mtd5), set the flags `sw_commit` / `sw_active` to `0` in U-Boot configuration.

To boot the second Image (mtd6 + mtd7), set the flags `sw_commit` / `sw_active` to `1` in U-Boot configuration.


# UART console (for access u-Boot\Linux OS in case of emergency)

![UART](https://github.com/stich86/UF-Instant-Mod/blob/main/uf-instant-ttl.png)
credits to [@robkegeenen](https://github.com/robkegeenen)

# Firmware switching

It's possible to switch between the two images in two ways:

1 - changing env `sw_active` and `sw_commit` env from u-Boot prompt (can be done using UART console \
2 - changing env `sw_active` and `sw_commit` from running Linux using command `nv setenv`

Env         | Value | Boot Bank
------------| ----- |-------
`sw_active` & `sw_commit` | `0`   | kernel0/root0
`sw_active` & `sw_commit` | `1`   | kernel1/root1

`nv setenv sw_active 0 && nv setenv sw_commit 0 && reboot` <-- *these commands switch to first image (if booted from second), using 1 doing the reverse*

# Factory reset after 10 boot

The stick with original firmware and without any other modification, use an u-Boot env called `bootlimit` that is configured with a value of `10`. There is another variable called `bootcount`, this one is increased on each CPU reset. When `bootlimit == bootcount`, u-Boot format partition `mtd3` and tries to download new configuration from tftpboot. With the modified firmware, that is using `mtd3` for configuration, create a little headache.

To avoid this problem there are two solutions:

1 - reset `bootcount` env on each boot of Linux OS, adding the command `nv setenv bootcount 0` on `rc35` file\
2 - disable `bootlimit` env setting it to `0`. Can be done with command `nv setenv bootlimit 0` on Linux OS

I prefer first approach, because if you screw up the `mtd3` partition with wrongs values, doing a fast swap for ten times (avoiding full Linux OS boot) will erase config partition and after OS boot, all parameters return to factory defaults

# Factory default parameters

Env           | Value
--------------| -----
`LAN_SDS_MODE`  | `1 (Fiber 1G)`
`IP_ADDRESS`    | `192.168.1.1`
`PON_MODE`      | `1 (GPON)`
`WAN_MODE`      | `1`
`PASSWORD`      | `admin`

# Flashing Custom Root FS
# MAKE SURE TO HAVE A BACKUP OF EACH MTD PARTITION BEFORE PROCEED!

If you have stick with stock firmware, you can login using ssh\telnet to IP `192.168.1.1` with these credentials `ubnt/ubnt`\
Verify with this command the installed images:

`nv getenv | grep sw_ver`

You should have an output like this:

```
sw_version0=v4.3.1.913-d48.210415.0811
sw_version1=v4.3.1.913-d48.210415.0811
```

So in this case the stick has already version `4.3.1` onboard (we will just need to preserv k0/k1 partitions). Now verify which boot bank are you using with this command:

`nv getenv | egrep "sw_active=|sw_commit="`

You should have an output like this:

```
sw_active=0
sw_commit=0
```

We are currently running `image0` on `mtd4/5` (refer to partition layout)

Now make sure you have `nc` command on your computer and follow this steps to write custom image on `image1` partition

- on the telnet\ssh session on UF-INSTANT, go to `cd /tmp`
- run this command: `nc -l -p 1234 > mtd7` (if you are on `image1`, use `mtd5` as name)
- on your computer, go where the custom root fs is downloaded `rootfs_MOD_UFINST_220505` (you can found it under folder *Modified RootFS* - md5 4ae50a56f5c4768ea5ac95d4298a01ba)
- run this command: `nc 192.168.1.1 1234 < rootfs_MOD_UFINST_220505`
- when done, on the telnet\ssh session your `nc` command has exited, you have a file called `mtd7` (or `mtd5`), run an md5sum on that file and compare the md5 with the original one, ONLY IF these are equal proceed with the next step
- now we need to erase `mtd3` (config) and `mtd7` (rootfs of image1) with these commands: `flash_eraseall mtd3` && `flash_eraseall mtd7` (replace with `mtd5` if you are doing from `image1`)
- after each erase complete, you should still into `/tmp` directory and run this command: `cat mtd7 > /dev/mtd7` (replace with `mtd5` if you are doing from `image1`)
- if there is no output error, we can activate the new rootfs and reboot on it. To do this run these commands: `nv setenv sw_active 1` && `nv setenv sw_commit 1` && `reboot`
- after about 2 minutes you should reach the stick via WebUI or telnet at IP `192.168.1.1`. NOTE: WebUI doesn't work if there is no fiber attached

If everything is working (obviously you have to setup the stick in the right way, I mean change GPON s/n, OLT mode and so on), you can follow the same proceedure for the other bank, or leave untouched. This will give you a fast way to restore the stick to its factory default just doing a `cat` of original rootFS to the modified one. Please rember that if you go back to stock firmware, it's mandatory to erase `mtd3` partion BEFORE rebooting.

# Basic configuration of the stick

Here is a example of commands that you can do via telnet to configure the stick, on each change a reboot is mandatory to apply:

```
  flash set GPON_SN YOURSN
  flash set OMCI_FAKE_OK 1
  flash set OMCI_OLT_MODE 1
  flash set PON_VENDOR_ID HWTC
```

For a full list and explanation, please refert to Anime4000 repo here: https://github.com/Anime4000/RTL960x/blob/main/Docs/FLASH_GETSET_INFO.md

# Customize RootFS

If you want, you can unsquash the custom RootFS and customized as you like (may be you want change WebUI colors or something else).
Remember to unsquash the file with `root` users because there are some special files that need super user permission, here is the two commands to extract/repack the file that then can be flashed on the stick:

*extract*

`unsquashfs rootfs_MOD_UFINST_220505`
this will create a folder called `squashfs-root` where you will find all the OS files inside

*repack*

`mksquashfs squashfs-root rootfs_MOD_UFINST_XXYYZZ -b 131072 -comp lzma`
