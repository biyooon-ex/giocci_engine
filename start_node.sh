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

#
# start node
#
echo "exec: 
MY_PROCESS_NAME=\"${MY_PROCESS_NAME}\" iex \
--name \"${NODE_NAME}@${NODE_IPADDR}\" \
--cookie \"${COOKIE}\" \
--erl \"-kernel inet_dist_listen_min ${INET_DIST_LISTEN_MIN} inet_dist_listen_max ${INET_DIST_LISTEN_MAX}\" -S mix
"

MY_PROCESS_NAME="${MY_PROCESS_NAME}" iex \
  --name "${NODE_NAME}@${NODE_IPADDR}" \
  --cookie "${COOKIE}" \
  --erl "-kernel inet_dist_listen_min ${INET_DIST_LISTEN_MIN} inet_dist_listen_max ${INET_DIST_LISTEN_MAX}" -S mix
