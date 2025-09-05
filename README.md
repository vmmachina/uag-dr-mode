# uag-dr-mode
Enabling Direct Routing on Omnissa UAG

Purpose

This PowerShell script automates the configuration required inside Omnissa Unified Access Gateway (UAG) appliances to support Direct Routing (DR mode) load balancing with Linux ipvsadm.

In DR mode, the Virtual IP (VIP) must exist on each UAG for packets to be accepted. At the same time, UAGs must not respond to ARP for the VIP, otherwise they would conflict with the load balancer. This script applies the necessary settings and makes them persistent across reboots.

⚠️ Important Note: Modifying the UAG internals in this way is not supported by Omnissa. Any redeployment or upgrade of a UAG will reset these changes. Re-run this script after each redeployment.

What the script does

Connects to a vCenter instance.

Runs guest commands inside the specified UAG VM (via VMware Tools / Invoke-VMScript).

Configures the VIP on loopback and suppresses ARP replies:

ip addr add <VIP>/32 dev lo
echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore
echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce
echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce


Appends the same commands to /etc/rc.local so they are applied at boot.

Ensures /etc/rc.local is executable.

Parameters

vCenter – Hostname or IP of the vCenter Server.

vmName – Name of the UAG VM in vCenter.

vip – Virtual IP address to assign for DR mode.

guestPassword – Root password of the UAG VM. (If omitted, you will be prompted securely.)

Example usage
.\Configure-UAG-DRMode.ps1 -vCenter vcsa.lab.local -vmName UAG01 -vip 10.10.210.99


You will be prompted for the root password unless passed explicitly.

Operational notes

This script must be run against each UAG in the load-balanced pool.

After UAG redeployment via PowerShell/OVA, re-run this script to re-apply settings.

Verify the VIP configuration inside the UAG with:

ip addr show lo
cat /proc/sys/net/ipv4/conf/lo/arp_ignore


For production, ensure this VIP matches the one configured on your load balancer’s VRRP instance.

Security

The script uses the root account to inject settings; restrict access to the script and credentials.

Passwords are not stored, but can be entered interactively to reduce exposure.

✅ With this script, DR-mode load balancing works seamlessly with UAG appliances: the LB owns ARP for the VIP, while UAGs silently accept packets addressed to it and reply directly to the default gateway, enabling full UDP + TCP Horizon protocol support.

Do you want me to also include a short troubleshooting section (e.g., “symptoms if ARP suppression is missing”)? That could make the README even more useful.
