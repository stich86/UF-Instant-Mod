# Modify Ufiber UF-Instant

This repo will contains modified RootFS and files used to convert UF-Instant SFP GPON stick from Vendor Lock-in to UFiber production to an open solution
GPON SFP is based on Realtek RTL9601CI chip. On the market there are ready OOB alternative, all mods are just for fun.

Please refer to Anime4000 repo for all other information and compatible sticks

https://github.com/Anime4000/RTL960x/

GUI on the modded firmware was made by Anime4000 :)

# Original firmwares from Ubiquiti

All files were extracted from OLT original firmware. *rootfs* files can be extracted with *unsquashfs* (parts of squashfs-tools)

# Partition Layout

Layout of MTD of UF-INSTANT is a little bit different from other Realtek Stick:

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

*mtd0 -> u-Boot*\
*mtd1/2 -> u-Boot Configuration*\
*mtd3 -> /var/config mount point where all stick configurations are saved*\
*mtd4-5 -> kernel0/rootfs0, for the first image. This can be booted setting flags "sw_commit/sw_active" to 0 on u-Boot configuration*\
*mtd6-7 -> kernel1/rootfs2, for the second image. This can be booted setting flags "sw_commit/sw_active" to 1 on u-Boot configuration*\
*mtd8 -> used by Europa Driver (laser controller), it contains all information about laser calibration, pay attention because is uniq for each stick!*\
*mtd9 -> partition used by original UF-INSTANT firmware to write parameters, not used by modified firmware*\
*mtd10-13 -> overlay partitions*

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

The stick with original firmware and without any other modification, use an u-Boot env called `bootlimit` that is configured with a value of 10. There is another variable called `bootcount`, this one is increased on each CPU reset. When `bootlimit == bootcount`, u-Boot format partition `mtd3` and tries to download new configuration from tftpboot. With the modified firmware, that is using `mtd3` for configuration, create a little headache.

To avoid this problem there are two solution:

1 - reset `bootcount` env on each boot of Linux OS, adding the command `nv setenv bootcount 0` on `rc35` file\
2 - disable `bootlimit` env setting it to `0`. Can be done with command `nv set bootlimit 0` on Linux OS\

I prefer first solution, because if you screw up the `mtd3` partition with wrongs values, doing a fast swap for ten times (so avoid full Linux OS boot) will erase config partition an start the stick in factory default

# Factory default parameters

Env           | Value
--------------| -----
`LAN_SDS_MODE`  | `1 (Fiber 1G)`
`IP_ADDRESS`    | `192.168.1.1`
`PON_MODE`      | `1 (GPON)`
`WAN_MODE`      | `1`
`PASSWORD`      | `admin`

