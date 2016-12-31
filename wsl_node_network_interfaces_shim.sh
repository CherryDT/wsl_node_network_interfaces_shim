#!/bin/bash
# ---------------------------------------------------------------------------
# wsl_node_network_interfaces_shim.sh - Installs/uninstalls a shim to prevent
# node from crashing when running in WSL when os.networkInterfaces is used

# Copyright 2016, "David Trapp",,, <dt@david-trapp.com>
  
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.

# Usage: wsl_node_network_interfaces_shim.sh [-h|--help] [-f|--force]
#        [install|uninstall]

# Revision history:
# 2016-12-29 Original version
# ---------------------------------------------------------------------------

PROGNAME=${0##*/}
VERSION="0.1"

echo "Network Interfaces shim for node.js under WSL"
echo "Copyright 2016, David Trapp"
echo

clean_up() { # Perform pre-exit housekeeping
  return
}

error_exit() {
  echo -e "${PROGNAME}: ${1:-"Unknown Error"}" >&2
  clean_up
  exit 1
}

graceful_exit() {
  clean_up
  exit
}

signal_exit() { # Handle trapped signals
  case $1 in
    INT)
      error_exit "Program interrupted by user" ;;
    TERM)
      echo -e "\n$PROGNAME: Program terminated" >&2
      graceful_exit ;;
    *)
      error_exit "$PROGNAME: Terminating on unknown signal" ;;
  esac
}

usage() {
  echo -e "Usage: $PROGNAME [-h|--help] [-f|--force] [install|uninstall]"
}

help_message() {
  cat <<- _EOF_
  $PROGNAME ver. $VERSION
  Installs/uninstalls a shim to prevent node from crashing when running in WSL
  when os.networkInterfaces is used

  $(usage)

  Options:
  -h, --help  Display this help message and exit.
  -f, --force Ignore check for shim installation status - can be used with
              "uninstall" to repair node symlink even if shim is broken
  
  Commands:
  install     Install the shim
  uninstall   Uninstall the shim

  NOTE: You must be the superuser to run this script.

_EOF_
  return
}

# Trap signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT"  INT

# Is this WSL?
if grep -q -v Microsoft /proc/sys/kernel/osrelease; then
  error_exit "Environment appears not to be WSL!\nYou probably don't even need this script."
fi

# Check for root UID
if [[ $(id -u) != 0 ]]; then
  error_exit "You must be the superuser to run this script."
fi

# Check if node is already installed
if [[ "$(which node)" == "/usr/bin/node" ]] && [[ "$(readlink $(which node))" == "/opt/wsl-node-shim/wsl-node-shim.sh" ]]; then
  SHIM_INSTALLED=1
else
  SHIM_INSTALLED=0
fi

# Write the shim JS file
write_shim_js() {

cat << _EOF_

var os = require('os');
try {
  os.networkInterfaces();
} catch(e) {
  os.networkInterfaces = function wslNodeShimNetworkInterfaces() {
    return {
      "Loopback Pseudo-Interface 1": [
        {
          address: '::1',
          netmask: 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
          family: 'IPv6',
          mac: '00:00:00:00:00:00',
          scopeid: 0,
          internal: true
        },
        {
          address: '127.0.0.1',
          netmask: '255.0.0.0',
          family: 'IPv4',
          mac: '00:00:00:00:00:00',
          internal: true
        }
      ]
    };
  };
}
_EOF_

}

# Write the shim SH file
write_shim_sh() {

cat << _EOF_
#!/bin/bash
/etc/alternatives/node -r /opt/wsl-node-shim/wsl-node-shim.js "\$@"
_EOF_

}

# Parse command-line
COMMAND=
FORCE=0
while [[ -n $1 ]]; do
  case $1 in
    -h | --help)
      help_message; graceful_exit ;;
    -f | --force)
      FORCE=1 ;;
    install)
      COMMAND=install ;;
    uninstall)
      COMMAND=uninstall ;;
    -* | --*)
      usage
      error_exit "Unknown option $1" ;;
    *)
      usage
      error_exit "Unknown command $1" ;;
  esac
  shift
done

# Main logic
case $COMMAND in
  install)
    if [[ $FORCE = 0 ]] && [[ $SHIM_INSTALLED = 1 ]]; then
      error_exit "Shim is already installed."
    fi
    if [[ "$(which node)" != "/usr/bin/node" ]]; then
      error_exit "node must be reachable via /usr/bin/node and\nin path, make sure node is installed correctly.\nIf this message appears after an unsuccessful shim installation, use:\n$0 uninstall -f"
    fi
    if [[ "$(readlink $(which node))" != "/etc/alternatives/node" ]]; then
      error_exit "/usr/bin/node must be linked to\n/etc/alternatives/node, make sure node is installed correctly.\nIf this message appears after an unsuccessful shim installation, use:\n$0 uninstall -f"
    fi
    rm -rf /opt/wsl-node-shim
    mkdir -p /opt/wsl-node-shim
    write_shim_js > /opt/wsl-node-shim/wsl-node-shim.js
    write_shim_sh > /opt/wsl-node-shim/wsl-node-shim.sh
    chmod +x /opt/wsl-node-shim/wsl-node-shim.sh
    rm /usr/bin/node
    ln -s /opt/wsl-node-shim/wsl-node-shim.sh /usr/bin/node
    echo "Shim installed!"
    echo "os.networkInterfaces() will not crash anymore but return only a loopback"
    echo "interface."
    echo "To test, run: node -e 'console.log(require(\"os\").networkInterfaces())'"
    ;;
  uninstall)
    if [[ $FORCE = 0 ]] && [[ $SHIM_INSTALLED = 0 ]]; then
      error_exit "Shim is not installed."
    fi
    if [[ ! -e /etc/alternatives/node ]]; then
      error_exit "/etc/alternatives/node must exist, please\nmake sure node is installed correctly."
    fi
    rm -rf /opt/wsl-node-shim
    rm /usr/bin/node
    ln -s /etc/alternatives/node /usr/bin/node
    echo "Shim uninstalled!"
    ;;
  "")
    if [[ $SHIM_INSTALLED = 1 ]]; then
      echo "Shim is currently installed"
    else
      echo "Shim is currently NOT installed"
    fi
    echo
    usage
    ;;
esac
    


graceful_exit

