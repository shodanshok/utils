#!/bin/bash

SLEEPTIME=5
LONGSLEEPTIME=60

#################### FUNCTIONS ####################

### VM RELATED
function check_exit_code {
        if [ ! $? = 0 ]
        then   
                GLOBAL_ERROR_STATUS=1
                CURRENT_ERROR_STATUS=$1
        fi
}

function check_run_status {
        RUN_STATUS=`virsh -q list | grep -i $IMAGE | wc -l`
}

function shutdown_vm {
        echo "Trying to stop the VM $IMAGE via ACPI"
        virsh shutdown $IMAGE
        sleep $LONGSLEEPTIME

        check_run_status
        if [ $RUN_STATUS -gt 0 ]
        then   
                echo "VM $IMAGE is not respondig. Re-trying shutdown via ACPI"
                virsh shutdown $IMAGE
                sleep $LONGSLEEPTIME
        fi

        check_run_status
        if [ $RUN_STATUS -gt 0 ]
        then   
                echo "VM $IMAGE is not respondig. Forcing shutdown"
                virsh destroy $IMAGE
                sleep $LONGSLEEPTIME
        fi
}

function suspend_vm {
        echo "Suspending VM $IMAGE"
        virsh suspend $IMAGE
        echo "Done"
        sleep $SLEEPTIME
}

function resume_vm {
        echo "Resuming VM $IMAGE"
        virsh resume $IMAGE
        echo "Done"
        sleep $SLEEPTIME
}

function managedsave_vm {
        echo "Saving VM $IMAGE"
        virsh managedsave $IMAGE
        echo "Done"
        sleep $SLEEPTIME
}

function restore_vm {
        echo "Restoring VM $IMAGE"
        virsh restore $SAVEPATH/$IMAGE.save
        echo "Done"
        sleep $SLEEPTIME
}

function start_vm {
        echo "Starting VM $IMAGE"
        virsh start $IMAGE
        sleep $LONGSLEEPTIME
}

function lvm_snapshot_create {
        echo "Snapshotting LVM volume $IMAGE"
        lvcreate -s --name $TEMPSNAP -L 50G $DATASTORE/$IMAGE.img
	exit_code=$?
	sleep $SLEEPTIME
        return $exit_code
}

function lvm_snapshot_remove {
        echo "Removing snapshot $TEMPSNAP"
        lvremove $DATASTORE/$TEMPSNAP -f
        exit_code=$?
	sleep $SLEEPTIME
	return $exit_code
}

### DRBD RELATED
function checkRole {
        when=$1
        targetRole=$2
        drbdadm role $resource | grep -i ^Primary > /dev/null
        if [ $? -eq 0 ]; then
                currentRole="Primary"
        fi
        drbdadm role $resource | grep -i ^Secondary > /dev/null
        if [ $? -eq 0 ]; then
                currentRole="Secondary"
        fi

        if [ $targetRole == $currentRole ] && [ $when == "before" ] ; then
                echo
                echo "You are already a $currentRole node. Nothing to do..."
                exit 0
        fi

        if [ $targetRole == $currentRole ] && [ $when == "after" ] ; then
                echo
                echo "You are now a $currentRole node."
        fi

        if [ $targetRole != $currentRole ] && [ $when == "after" ] ; then
                echo
                echo "An ERROR happened. You remain a $currentRole node!"
        fi

}

function checkIfOtherPrimary {
        drbdadm role $resource | grep -i Primary > /dev/null
        if [ $? -eq 0 ]; then
                otherPrimary="yes"
        else
		otherPrimary="no"
	fi
}

#################### FUNCTIONS ####################
