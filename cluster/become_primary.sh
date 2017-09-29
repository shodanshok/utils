#!/bin/bash
source ./functions.sh

if [ $? -gt 0 ]; then
	echo "Can not import functions. Exiting..."
	exit 1
fi

drbdconf="/etc/drbd.d/global_common.conf"
resource="vol1"
overlay="/opt/vol1"
randsuffix=$RANDOM

checkRole "before" "Primary"
checkIfOtherPrimary

if [ $otherPrimary == "yes" ]; then
	echo
	echo "WARNING!"
	echo "Another primary node was detected."
	echo "No changes done."
	exit 1
fi

echo
echo "WARNING!"
echo "To become the Primary node, you must have the other node operating in Secondary mode. Two primary nodes are not supported, and DRBD will abort in this case."
read -p "Do you want to continue? (y/N)" confirm

if [ -z $confirm ] || ( [ ! $confirm == "y" ] && [ ! $confirm == "Y" ] ); then
	echo "Exiting. No changes done."
	exit 0
fi

read -p "Did you put the other nodes in Secondary mode? (y/N)?" confirm

if [ -z $confirm ] || ( [ ! $confirm == "y" ] && [ ! $confirm == "Y" ] ); then
        echo "Exiting. No changes done."
        exit 0
fi

echo "Phase 1: switching DRBD to primary role"
drbdadm primary $resource
echo

echo "Phase 2: mounting overlay filesystem"
mount $overlay
echo

echo "Phase 3: starting drbdlinks"
drbdlinks start
echo

echo "Phase 4: reloading libvirtd configuration"
read -p "Did you want to restart the virtual machines (y/N)?" confirm
if [ $confirm == "y" ] || [ $confirm == "Y" ] ; then
	service virtlogd stop
	service virtlockd stop
        service libvirtd restart

else
	echo "You had to manually restart libvirtd and related services"
fi
chkconfig libvirtd on
echo

checkRole "after" "Primary"
echo
if [ $currentRole == "Primary" ]; then
echo "Phase 5: set DRBD 'become-primary-on'"
	sed -i s/#.*become-primary-on/become-primary-on/ $drbdconf
fi

drbd-overview
echo
