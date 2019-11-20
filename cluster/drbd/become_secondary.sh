#!/bin/bash
source ./functions.sh

if [ $? -gt 0 ]; then
	echo "Can not import functions. Exiting..."
	exit 1
fi

drbdconf="/etc/drbd.d/global_common.conf"
resource="vol1"
overlay="/opt/vol1"
timeout=120

checkRole "before" "Secondary"

echo
echo "WARNING!"
echo "This will stop *any* virtual machines and put DRBD into secondary mode"
read -p "Do you want to continue? (y/N)" confirm

if [ -z $confirm ] || ( [ ! $confirm == "y" ] && [ ! $confirm == "Y" ] ); then
	echo "Exiting. No changes done."
	exit 0
fi

echo "We don't undestand each other."
echo "If you continue, I will STOP ANY VIRTUAL MACHINES."
read -p "Are you really really *really* sure (y/N)?" confirm

if [ -z $confirm ] || ( [ ! $confirm == "y" ] && [ ! $confirm == "Y" ] ); then
        echo "Exiting. No changes done."
        exit 0
fi

echo "Phase 1: unsetting DRBD 'become-primary-on'"
sed -i s/become-primary-on/#become-primary-on/ $drbdconf

echo "Phase 2: stopping virtual machines. This can take some time (timout: $timeout seconds)..."
for stopping in `virsh list --name`; do
        echo "Shutdown: $stopping"
        virsh shutdown $stopping
done
for second in `seq 1 $timeout`; do
	running=`virsh list --name`
	if [ ! -z $running ]; then
		echo -n "."
		sleep 1
	else
		break
	fi
done
echo

echo "Phase 3: forced destroy of unresponding virtual machines"
for victim in `virsh list --name`; do
	echo "Destroy: $victim"
	virsh destroy $victim
done
if [ -z $victim ]; then
	echo "No unresponding virtual machines found (good!)"
fi
service libvirtd stop
service virtlogd stop
service virtlockd stop
echo

echo "Phase 4: unmounting overlay filesystem"
umount $overlay
echo

echo "Phase 5: stopping drbdlinks"
drbdlinks -v stop
echo

echo "Phase 6: switching to DRBD secondary role"
drbdadm secondary $resource
echo

checkRole "after" "Secondary"
drbd-overview
echo
