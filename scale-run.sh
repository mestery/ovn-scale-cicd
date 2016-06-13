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
docker exec ovn-rally rally-ovs task start /root/rally-ovn/workload/create-sandbox-ovn-rally.json

# Run tests
docker exec ovn-rally rally-ovs task start /root/rally-ovn/workload/create_networks.json

popd
