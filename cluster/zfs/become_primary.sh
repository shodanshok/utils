#!/bin/bash
set -u
IFS=$'\n\t'

timeout=5
unixtime=`date +%s`
datastore="tank/kvm"

echo
echo "WARNING!"
echo "To become the Primary node, you must have the other node operating in Secondary mode and the datastore must be synchronized. Otherwise, dataloss *will* occour."
read -p "Do you want to continue? (y/N) " confirm

if [ -z $confirm ] || ( [ ! $confirm == "y" ] && [ ! $confirm == "Y" ] ); then
	echo "Exiting. No changes done."
	exit 0
fi

read -p "Did you put the other nodes in Secondary mode? (y/N)? " confirm

if [ -z $confirm ] || ( [ ! $confirm == "y" ] && [ ! $confirm == "Y" ] ); then
        echo "Exiting. No changes done."
        exit 0
fi

echo "Phase 1: resetting ssh authorized_keys"
mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.$unixtime

echo "Phase 2: setting datastore in read-write state"
zfs set readonly=off $datastore

echo "Phase 3: linking /etc/libvirt"
mv /etc/libvirt /etc/libvirt.$unixtime
ln -s "/$datastore/etc/libvirt" /etc/
restorecon -F /etc/libvirt

echo "Phase 4: enabling libvirtd and autostarting virtual machines"
systemctl enable libvirtd; systemctl restart libvirtd
