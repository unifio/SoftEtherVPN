#!/bin/bash
set -e
ADMIN_PASS=${ADMIN_PASS:-}
VPN_HOST=${VPN_HOST:-}
VPN_PORT=${VPN_PORT:-}
USERS=${USERS:-}
vpncmd_server () {
  /usr/bin/vpncmd ${VPN_HOST}:${VPN_PORT} /SERVER /PASSWORD:${ADMIN_PASS} /CMD "$@"
}

vpncmd_hub () {
  /usr/bin/vpncmd ${VPN_HOST}:${VPN_PORT} /SERVER /PASSWORD:${ADMIN_PASS} /ADMINHUB:DEFAULT /CMD "$@"
}
gen_ovpn_certs () {
  # vpncmd_server OpenVpnEnable yes /PORTS:1194
  vpncmd_server OpenVpnMakeConfig openvpn.zip 2>&1 > /dev/null
  # extract .ovpn config
  unzip -p openvpn.zip *_l3.ovpn > softether.ovpn
  # delete "#" comments, \r, and empty lines
  sed -i '/^#/d;s/\r//;/^$/d' softether.ovpn
  # send to stdout
  cat softether.ovpn
}
set_server_certs () {
  # set server certificate & key
  if [[ -f server.crt && -f server.key ]]; then
    vpncmd_server ServerCertSet /LOADCERT:server.crt /LOADKEY:server.key

  elif [[ "*${CERT}*" != "**" && "*${KEY}*" != "**" ]]; then
    # server cert/key pair specified via -e
    CERT=$(echo ${CERT} | sed -r 's/\-{5}[^\-]+\-{5}//g;s/[^A-Za-z0-9\+\/\=]//g;')
    echo -----BEGIN CERTIFICATE----- > server.crt
    echo ${CERT} | fold -w 64 >> server.crt
    echo -----END CERTIFICATE----- >> server.crt

    KEY=$(echo ${KEY} | sed -r 's/\-{5}[^\-]+\-{5}//g;s/[^A-Za-z0-9\+\/\=]//g;')
    echo -----BEGIN PRIVATE KEY----- > server.key
    echo ${KEY} | fold -w 64 >> server.key
    echo -----END PRIVATE KEY----- >> server.key

    vpncmd_server ServerCertSet /LOADCERT:server.crt /LOADKEY:server.key
    rm server.crt server.key
    export KEY='**'
  fi
}

disable_ext_logs () {
  # disable extra logs
  vpncmd_hub LogDisable packet
  vpncmd_hub LogDisable security

  # force user-mode SecureNAT
  vpncmd_hub ExtOptionSet DisableIpRawModeSecureNAT /VALUE:true
  vpncmd_hub ExtOptionSet DisableKernelModeSecureNAT /VALUE:true
}
# See if user exists
checkUser () {
  echo "$0"
}
adduser () {
    printf " $1"
    vpncmd_hub UserCreate $1 /GROUP:none /REALNAME:none /NOTE:none
    vpncmd_hub UserPasswordSet $1 /PASSWORD:$2
}
create_users () {
  printf '# Creating user(s):'

  if [[ $USERS ]]
  then
    while IFS=';' read -ra USER; do
      for i in "${USER[@]}"; do
        IFS=':' read username password <<< "$i"
        # echo "Creating user: ${username}"
        adduser $username $password
      done
    done <<< "$USERS"
  else
    adduser $USERNAME $PASSWORD
  fi

  echo

  export USERS='**'
  export PASSWORD='**'
}
run_vpncmds () {
  # handle VPNCMD_* commands right before setting admin passwords
  if [[ $VPNCMD_SERVER ]]
  then
    while IFS=";" read -ra CMD; do
      vpncmd_server $CMD
    done <<< "$VPNCMD_SERVER"
  fi

  if [[ $VPNCMD_HUB ]]
  then
    while IFS=";" read -ra CMD; do
      vpncmd_hub $CMD
    done <<< "$VPNCMD_HUB"
  fi
}
set_hub_pass () {
  # set password for hub
  : ${HPW:=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 16 | head -n 1)}
  vpncmd_hub SetHubPassword ${HPW}
}
set_server_pass () {
  # set password for server
  : ${SPW:=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 20 | head -n 1)}
  vpncmd_server ServerPasswordSet ${SPW}

}
stop_server () {
  /usr/bin/vpnserver stop 2>&1 > /dev/null
  # while-loop to wait until server goes away
  set +e
  while [[ $(pidof vpnserver) ]] > /dev/null; do sleep 1; done
  set -e
}

[[ -n $ADMIN_PASS ]] && [[ -n $VPN_HOST ]] && [[ -n $VPN_PORT ]] && [[ -n $USERS ]] && create_users
