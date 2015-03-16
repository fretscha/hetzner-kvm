# hetzner-kvm
Scripts to build a minimal kvm infrastructure on Hetzner root servers.

A few years ago I moved most of my projects to Hetzner root servers (https://www.hetzner.de/).

Recently I repeated my installation steps and they still seem to work. (lucky me!)
Below you will find the installation steps to set up from scratch kvm host and guests.

###Features

* Ubuntu host and guest
* Logical Volume based guests
* automated guest installation from scratch (no images)

Please post an issue in case somthing won't work.

## Install the kvm host

>**WARNING: following these procedures _will cause the deletion_ of all your data on your root server harddisks.**

### Boot from rescue system
1. Log in to https://robot.your-server.de/ and activate the Linux 64bit rescue system.
1. Copy the rescue system password for later use.
1. Restart the server. Your server will boot a Hetzner Image over the network.
1. Log in with your rescue system password.

### Configure and install KVM host
1. Replace the value `host.example.tld` with the fully qualified domain name of your host.
1. In this example I used `SWRAID 0` for *striping* because I only have 2 x 240GB of diskspace. You are free to use `SWRAID 1` for *mirroring*. ;)
1. We build
   ```bash
   tee /autosetup <<EOF
   DRIVE1 /dev/sda
   DRIVE2 /dev/sdb
   SWRAID 0
   BOOTLOADER grub
   HOSTNAME host.example.com
   PART   /boot    ext3   2G
   PART   lvm      vg0    all
   LV    vg0    root    /         ext3            20G
   LV    vg0    swap    swap      swap            16G
   LV    vg0    tmp     /tmp      ext3             5G

   IMAGE images/Ubuntu-1410-utopic-64-minimal.tar.gz
   EOF
   ```
1. Partition and install the os as configured with the command ```installimage```. The script will create the partitions as defined, make the filesystems and mount them. Then the OS image is copied into the partitions and grub will install the boot sector to boot from the installed kernel.
1. Reboot the server and start from the newly installed OS. Keep in mind that the rescue password is still the initial root password on your system.

### Prepare the KVM host
1. Login as user `root` and copy your public ssh key to the system.

   ```bash
   ssh root@host.example.tld
   exit
   ssh-copy-id root@host.example.tld
   ssh root@host.example.tld # without password
   ```
1. Add the second disk to the volume group

   ```bash
   parted -a optimal /dev/sdb mkpart primary 0% 100%
   parted -s /dev/sdb set 1 lvm on
   vgextend vg0 /dev/sdb1
   #show the volume group
   vgdisplay
   ```
1. Update and install needed packages

   ```bash
   #update packages
   apt-get update && apt-get dist-upgrade -y
   #install kvm related packages
   apt-get install -y qemu-kvm libvirt-bin bridge-utils ubuntu-vm-builder
   #install guest building dependencies
   apt-get install -y python-pip bc
   pip install passlib
   ```

### Configure Network
After installing the kvm packages a *internal* private network should be installed. To add additional public IP some changes to the system are needed.

To enable ip4 ip forwarding ensure to uncomment following in `/etc/sysctl.conf` for persistence
```bash
net.ipv4.ip_forward=1
```

For instant activation:
```bash
sysctl -p /etc/sysctl.conf
```

To add a public network `public100` to the configuration save the following to `public100.xml`. Replace The IP address and netmask with the one you recieved from Hetzner.
```xml
<network>
  <name>public100</name>
  <forward dev='eth0' mode='route'>
  <interface dev='eth0'/>
  </forward>
  <bridge name='virbr100' stp='on' delay='0'/>
  <ip address='xxx.xxx.xxx.xxx' netmask='255.255.255.xxx'>
  </ip>
</network>
```

```bash
virsh net-create public100.xml
```
This will create the defined network.

To autostart the network on boot, use the following `virsh` commands.

```bash
# because of a bug please, add a newline at the end of the file and save the file
virsh net-edit public100
# and now the autostart will work
virsh net-autostart public100
# show all available, active networks
virst net-list
```
## Running the guest.build script
All script are asuming that you are *root* and running them in `/root`.

###Presets
I suggest to checkout the repository e.g. in `/root/hetzner-kvm`

Copy `/root/hetzner-kvm/guest.builder.example` to `/root/.guest.builder` and edit it accordingly to your IP addresses and subnets

Copy `/root/hetzner-kvm/boot.sh` to `/root/boot.sh` and customize it to your needs. This is the file which is started at first boot.
`
