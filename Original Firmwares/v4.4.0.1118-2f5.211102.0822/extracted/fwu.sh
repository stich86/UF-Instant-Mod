#!/bin/sh

# luna firmware upgrade  script
# $1 image destination (0 or 1) 
# Kernel and root file system images are assumed to be located at the same directory named uImage and rootfs respectively
# ToDo: use arugements to refer to kernel/rootfs location.

k_img="uImage"
r_img="rootfs"
u_img="plr.img"
img_ver="fwu_ver"
md5_cmp="md5.txt"
md5_cmd="/bin/md5sum"
#md5 run-time result
md5_tmp="md5_tmp" 
md5_rt_result="md5_rt_result.txt"

# Stop this script upon any error
#set -e

echo "Updating image $1 with file $2 offset $3"
img=$2
img_offset=$3

# Find out kernel/rootfs mtd partition according to image destination
k_mtd="/dev/"`cat /proc/mtd | grep \"k"$1"\" | sed 's/:.*$//g'`
r_mtd="/dev/"`cat /proc/mtd | grep \"r"$1"\" | sed 's/:.*$//g'`
u_mtd="/dev/mtd0"
echo "kernel image is located at $k_mtd"
echo "rootfs image is located at $r_mtd"

k_img_size_dec=$(dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -tv $k_img |  awk '{print $3}')
r_img_size_dec=$(dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -tv $r_img |  awk '{print $3}')
u_img_size_dec=$(dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -tv $u_img |  awk '{print $3}')
echo "$k_img size $k_img_size_dec, $r_img size $r_img_size_dec, $u_img size $u_img_size_dec"

if [ -z "$k_img_size_dec" -o -z "$r_img_size_dec" ]; then
    echo "Invalid sizes"
    exit 1
fi

# Extract kernel image
dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -x $k_img -O | md5sum | sed 's/-/'$k_img'/g' > $md5_rt_result
# Check integrity
grep $k_img $md5_cmp > $md5_tmp
diff $md5_rt_result $md5_tmp

if [ $? != 0 ]; then
    echo "$k_img""md5_sum inconsistent, aborted image updating !"
    exit 1
fi

# Extract rootfs image
dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -x $r_img -O | md5sum | sed 's/-/'$r_img'/g' > $md5_rt_result
# Check integrity
grep $r_img $md5_cmp > $md5_tmp
diff $md5_rt_result $md5_tmp

if [ $? != 0 ]; then
    # rm $r_img
    echo "$r_img""md5_sum inconsistent, aborted image updating !"
    exit 1
fi

# Extract uboot image
if [ -n "$u_img_size_dec" ]; then
    dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -x $u_img -O | md5sum | sed 's/-/'$u_img'/g' > $md5_rt_result
    # Check integrity
    grep $u_img $md5_cmp > $md5_tmp
    diff $md5_rt_result $md5_tmp
    if [ $? != 0 ]; then
        echo "$u_img""md5_sum inconsistent, aborted image updating !"
        exit 1
    fi
fi

echo "Integrity of $k_img & $r_img is okay, start updating"

erase_mtd()
{
    # get erase block size and test support of -x argument
    eb_size=$(flash_erase -q -x -s $1 0 1 2>/dev/null)
    if [ $? -eq 0 ]; then
        erase_args=-x
    else
        erase_args=
        eb_size=4096
    fi

    flash_erase $erase_args $1 0 $(((($2 - 1) / $eb_size) + 1))
}

# Upgrade uboot
if [ -n "$u_img_size_dec" ]; then
    echo "Checking uboot version"
    dd if=$u_mtd bs=$u_img_size_dec count=1 2>/dev/null | md5sum | sed 's/-/'$u_img'/g' > $md5_rt_result
    grep $u_img $md5_cmp > $md5_tmp
    diff $md5_rt_result $md5_tmp
    if [ $? != 0 ]; then
        echo "Upgrading uboot"
        erase_mtd $u_mtd $u_img_size_dec
        echo "Writing $u_img to $u_mtd"
        #dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -x $u_img -O |wc -c
        dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -x $u_img -O > $u_mtd
    else
        echo "Uboot is up to date"
    fi
fi

# Erase kernel partition 
erase_mtd $k_mtd $k_img_size_dec
# Write kernel partition
echo "Writing $k_img to $k_mtd"
dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -x $k_img -O > $k_mtd

# Erase rootfs partition 
erase_mtd $r_mtd $r_img_size_dec
# Write rootfs partition
echo "Writing $r_img to $r_mtd"
dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -x $r_img -O > $r_mtd


# Write image version information 
dd if=$img bs=$img_offset skip=1 2>/dev/null | tar -x $img_ver
nv setenv sw_version"$1" "`cat $img_ver`"

# Clean up temporary files
rm -f $md5_cmp $md5_tmp $md5_rt_result $img_ver $2

# Post processing (for future extension consideration)

echo "Successfully updated image $1!!"

