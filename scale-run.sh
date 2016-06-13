#!/bin/bash

# Read variables
source ovn-scale.conf

mkdir -p $OVN_DOCKER_ROOT
pushd $OVN_DOCKER_ROOT

# Install OVN Scale Test
if [ ! -d $OVN_SCALE_REPO_NAME ]; then
    git clone $OVN_SCALE_REPO
    pushd $OVN_SCALE_REPO_NAME
    git fetch
    git checkout $OVN_SCALE_BRANCH
    popd
fi

# Build the docker containers
pushd $OVN_SCALE_REPO_NAME
cd ansible/docker
make
popd

# Deploy the containers
pushd $OVN_SCALE_REPO_NAME
sudo /usr/local/bin/ansible-playbook -i $OVN_DOCKER_HOSTS ansible/site.yml -e @$OVN_DOCKER_VARS -e action=deploy
popd

# Create the rally deployment
docker exec ovn-rally rally-ovs deployment create --file /root/rally-ovn/ovn-multihost-deployment.json --name ovn-multihost

# Register the emulated sandboxes in the rally database
docker exec ovn-rally rally-ovs task start /root/rally-ovn/workload/create-sandbox-$OVN_RALLY_HOSTNAME.json
TASKID=$(docker exec ovn-rally rally task list --uuids-only)
docker exec ovn-rally rally task report $TASKID --out /root/create-sandbox-output.html
docker exec ovn-rally rally task delete --uuid $TASKID

# Run tests
docker exec ovn-rally rally-ovs task start /root/rally-ovn/workload/create_networks.json
TASKID=$(docker exec ovn-rally rally task list --uuids-only)
docker exec ovn-rally rally task report $TASKID --out /root/create-networks-output.html
docker exec ovn-rally rally task delete --uuid $TASKID

docker exec ovn-rally rally-ovs task start /root/rally-ovn/workload/create_and_list_lports.json
TASKID=$(docker exec ovn-rally rally task list --uuids-only)
docker exec ovn-rally rally task report $TASKID --out /root/create-and-list-lports-output.html
docker exec ovn-rally rally task delete --uuid $TASKID

docker exec ovn-rally rally-ovs task start /root/rally-ovn/workload/create_and_bind_ports.json
TASKID=$(docker exec ovn-rally rally task list --uuids-only)
docker exec ovn-rally rally task report $TASKID --out /root/create-and-bind-ports-output.html
docker exec ovn-rally rally task delete --uuid $TASKID

popd
