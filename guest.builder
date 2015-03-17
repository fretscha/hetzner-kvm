#!/bin/bash
# ---------------------------------------------------------------------------
#  kvm guest builder

# Copyright 2015, Frederic Tschannen

# Revision history:
# 2015-03-15  1.0.0  Created
# ---------------------------------------------------------------------------

PROGNAME=${0##*/}

VERSION="1.0.0"

source ~/.guest_builder
# mandatory variables :  netmask, broadcast, gateway, vm_network


# disk size in GB
if [ -z "${volsize}" ]; then
    echo "set env var 'volsize' to an reasonable size in GB, eg 8, 16, 40 or 80 "
    exit 42
fi

# mandatory environment variable
if [ -z "${vm_fqdn}" ]; then
    echo "set env var 'vm_fqdn' to the name of the desired guest VM"
    exit 42
fi

# optional param
if [ -z "${vm_guestip}" ]; then
    vm_guestip=$(dig $vm_fqdn +short)
fi

# mandatory if not resolvable by DNS
if [ -z "${vm_guestip}" ]; then
    echo "ensure DNS resolution vm_fqdn or set env var 'vm_guestip' to the IP of the desired guest VM"
    exit 42
fi

vm_hostname=$(echo $vm_fqdn |awk -F. '{ print $1 }')
vm_domain=$(echo $vm_fqdn |awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//')

# Ubuntu suite, default utopic
if [ -z "${suite}" ]; then
    suite="utopic"
fi

# memory size in GB, default 2 GB
if [ -z "${guest_memory}" ]; then
    guest_memory=2
fi

# swapsize in MB, equal to memoryzize
swapsize=$(echo "${guest_memory}*1024" | bc)
echo "swapsize = ${swapsize}"

# memorysize in MB
memorysize=$(echo "${guest_memory}*1024" | bc)
echo "memorysize = ${memorysize}"

# rootsize in MB
rootsize=$(echo "${volsize}*1024-${swapsize}" | bc)
echo "rootsize = ${rootsize}"

user_pass=$(python -c "from passlib.utils import generate_password; print(generate_password(size=32))")
echo "pass = ${user_pass}"

echo "*** vm_fqdn ${vm_fqdn}"
echo "*** vm_hostip ${vm_guestip}"
echo "*** vm_hostname ${vm_hostname}"
echo "*** VM_domain ${vm_domain}"
read -p "Press any key..."

# cleanup
echo "---> Remove existing guest with same hostname"
virsh destroy $vm_fqdn
virsh undefine $vm_fqdn
lvremove -f /dev/vg0/$vm_fqdn
sleep 1
rmdir $vm_hostname
echo "---> Start"

lvcreate --size ${volsize}G --name $vm_fqdn vg0

ubuntu-vm-builder kvm trusty \
 -o --libvirt qemu:///system \
 --debug \
 --arch amd64 \
 --domain $vm_domain \
 --hostname $vm_hostname \
 --tmpfs - \
 --kernel-flavour server \
 --mem $memorysize \
 --cpus 2 \
 --rootsize $rootsize \
 --swapsize $swapsize \
 --raw /dev/mapper/vg0-$vm_fqdn \
 --firstboot /root/boot.sh \
 --user deploy \
 --pass $user_pass \
 --ssh-key /root/.ssh/authorized_keys \
 --network $vm_network \
 --ip $vm_guestip \
 --mask $netmask \
 --bcast $broadcast \
 --gw $gateway \
 --mirror http://mirror.hetzner.de/ubuntu/packages \
 --addpkg acpid \
 --addpkg openssh-server \
 --addpkg git \
 --addpkg aptitude \
 --addpkg linux-image-generic ;
sleep 5

echo

#change libvirt name to fqdn
virsh dumpxml $vm_hostname > $vm_fqdn.xml
virsh undefine $vm_hostname
sed -i "s/<name>$vm_hostname<\/name>/<name>$vm_fqdn<\/name>/g" $vm_fqdn.xml
virsh define $vm_fqdn.xml

virsh start $vm_fqdn
virsh autostart $vm_fqdn

sleep 3

ping -c 10 $vm_fqdn
