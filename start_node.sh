#!/bin/sh

#
# set variables
#
NODE_NAME="engine"
NODE_IPADDR="192.168.10.101"
COOKIE="idkp"
INET_DIST_LISTEN_MIN="9100"
INET_DIST_LISTEN_MAX="9155"
MY_PROCESS_NAME="{:global, :engine}"


MY_NODE_NAME="engine1"
NODE_RELAY_NAME1="relay1"
NODE_RELAY_NAME2="relay2"
NODE_RELAY_NAME3="relay3"
#
# start node
#
echo "exec: 
MY_NODE_NAME=\"${MY_NODE_NAME}\" MY_PROCESS_NAME=\"${MY_PROCESS_NAME}\" NODE_RELAY_NAME1=\"${NODE_RELAY_NAME1}\" NODE_RELAY_NAME2=\"${NODE_RELAY_NAME2}\" NODE_RELAY_NAME3=\"${NODE_RELAY_NAME3}\"iex \
--name \"${NODE_NAME}@${NODE_IPADDR}\" \
--cookie \"${COOKIE}\" \
--erl \"-kernel inet_dist_listen_min ${INET_DIST_LISTEN_MIN} inet_dist_listen_max ${INET_DIST_LISTEN_MAX}\" -S mix
"

MY_NODE_NAME="${MY_NODE_NAME}" MY_PROCESS_NAME="${MY_PROCESS_NAME}" NODE_RELAY_NAME1="${NODE_RELAY_NAME1}" NODE_RELAY_NAME2="${NODE_RELAY_NAME2}" NODE_RELAY_NAME3="${NODE_RELAY_NAME3}" iex \
  --name "${NODE_NAME}@${NODE_IPADDR}" \
  --cookie "${COOKIE}" \
  --erl "-kernel inet_dist_listen_min ${INET_DIST_LISTEN_MIN} inet_dist_listen_max ${INET_DIST_LISTEN_MAX}" -S mix
