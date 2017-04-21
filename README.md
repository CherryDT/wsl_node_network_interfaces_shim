## This workaround is now obsolete because the underlying issue in Windows was fixed and the fix has now been released to the public as part of the Creators Update on April 11th, 2017.

-----

# wsl_node_network_interfaces_shim
_A shim to prevent node from crashing when running in WSL when os.networkInterfaces is used_

The Windows Subsystem for Linux (WSL) is great. However, it still has some issues. One of them is that network interface management isn't implemented yet. Because of that, the `os.networkInterfaces` function in node.js will crash with `EINVAL`. Here is the [GitHub issue about this problem](https://github.com/Microsoft/BashOnWindows/issues/468).

## Workaround

**TL;DR**: A quick fix for this problem would be running the following command: `curl https://raw.githubusercontent.com/CherryDT/wsl_node_network_interfaces_shim/master/wsl_node_network_interfaces_shim.sh > /tmp/wslfix.sh && chmod +x /tmp/wslfix.sh && sudo /tmp/wslfix.sh install`

If this fails with an error, read below.

-----

My current workaround is shimming the `os.networkInterfaces` function by shimming node to load my shim file... ;) I'm replacing the `/usr/bin/node` symlink to link to an intermediate script file which invokes the real node with an extra `-r` argument to require a JS file at start, in which I'm replacing the `os.networkInterfaces` function to return a loopback interface.

Basically, this shim will prevent the crash when any node script calls `os.networkInterfaces()`. It will not make the network interfaces work correctly, though - the scripts will always just see the loopback interface, but no actual interfaces. Still, this solves a lot of problems already.

I created a bash script which does the dirty work for you.

* Make sure you have node installed the "normal" way so that `/etc/alternatives/node` exists. (It usually does when installing a modern node version from the nodesource repositories.)
* Download the script from this repository manually, or:
  - If you don't have a `~/bin` folder, create it: `mkdir ~/bin` and close and reopen bash so bash will detect it and add it to the path. (The script doesn't _have_ to be installed in `~/bin`, I just found it convenient.)
  - Run `curl https://raw.githubusercontent.com/CherryDT/wsl_node_network_interfaces_shim/master/wsl_node_network_interfaces_shim.sh > ~/bin/wsl_node_network_interfaces_shim.sh && chmod +x ~/bin/wsl_node_network_interfaces_shim.sh`
* Install the shim: `sudo wsl_node_network_interfaces_shim.sh install`
* Test it: `node -e 'console.log(require("os").networkInterfaces())'` (should output a loopback interface instead of failing)

To uninstall the shim again, use: `sudo wsl_node_network_interfaces_shim.sh uninstall`
In case anything goes wrong and the script left you in a state in which you can't use node, use: `sudo wsl_node_network_interfaces_shim.sh uninstall -f`

By the way, the shim will always check whether the real `os.networkInterfaces` function fails before replacing it. If it does not fail (for example, you updated Windows to a build which fixes the problem natively), it will not replace it.
