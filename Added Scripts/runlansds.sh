#!/bin/sh

lan_sds_mode=`flash get LAN_SDS_MODE | sed 's/LAN_SDS_MODE=//g'`
echo $lan_sds_mode > proc/lan_sds/lan_sds_cfg
echo 1 > proc/lan_sds/sfp_app
sfpapp &
