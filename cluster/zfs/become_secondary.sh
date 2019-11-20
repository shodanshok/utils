#!/bin/bash
set -u
IFS=$'\n\t'

timeout=5
unixtime=`date +%s`
datastore="tank/kvm"

echo
echo "WARNING!"
echo "This will stop *any* virtual machines and put the host into secondary mode"
read -p "Do you want to continue? (y/N) " confirm

if [ -z $confirm ] || ( [ ! $confirm == "y" ] && [ ! $confirm == "Y" ] ); then
	echo "Exiting. No changes done."
	exit 0
fi

echo "Phase 1: stopping virtual machines"
for stopping in `virsh list --name`; do
        echo "Shutdown: $stopping"
        virsh shutdown $stopping; virsh shutdown $stopping
done
sleep $timeout;

echo "Phase 2: forced destroy of unresponding virtual machines"
for victim in `virsh list --name`; do
	echo "Destroy: $victim"
	virsh destroy $victim
done
killall qemu-kvm

echo "Phase 3: stopping and disabling libvirtd service"
systemctl stop libvirtd; systemctl disable libvirtd

echo "Phase 4: renaming /etc/libvirtd"
mv /etc/libvirt /etc/libvirt.$unixtime

echo "Phase 5: setting datastore in read-only state"
zfs set readonly=on $datastore
