#!/bin/bash

OVN_DOCKER_ROOT=${OVN_DOCKER_ROOT:-~/ovn-docker}

OVN_SCALE_REPO=${OVN_SCALE_REPO:-https://github.com/openvswitch/ovn-scale-test.git}
OVN_SCALE_REPO_NAME=$(basename ${OVN_SCALE_REPO} | cut -f1 -d'.')
OVN_SCALE_BRANCH=${OVN_SCALE_BRANCH:-origin/master}

# The hosts file to use
OVN_DOCKER_HOSTS=${OVN_DOCKER_HOSTS:-./ansible/docker-ovn-hosts}
OVN_DOCKER_VARS=${OVN_DOCKER_VARS:-./ansible/all.yml}

# Install prerequisites
sudo apt-get install -y apt-transport-https ca-certificates
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

if [ ! -f /etc/apt/sources.list.d/docker.list ] ; then
    sudo su -c 'echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list' 
    sudo apt-get update -y
    sudo apt-get purge -y lxc-docker 
    sudo apt-get install -y apparmor
fi

# Install the docker engine
sudo apt-get install -y docker-engine
sudo service docker start

# Create a docker group and add ubuntu user to this group
EXISTING_DOCKER=$(cat /etc/group | grep docker)
if [ "$EXISTING_DOCKER" == "" ]; then
    sudo groupadd docker
    sudo usermod -aG docker ubuntu
    echo "WARNING: The docker group was created and the ubuntu user added to this group."
    echo "         Please reboot the box, log back in, and re-run $0."
    exit 1
fi

# Install python dependencies
sudo apt-get install -y python-pip
sudo pip install --upgrade pip
sudo pip install -U docker-py netaddr
sudo apt-get remove -y ansible
sudo pip install ansible==2.0.2.0

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

# Clean everything up
pushd $OVN_SCALE_REPO_NAME
sudo /usr/local/bin/ansible-playbook -i $OVN_DOCKER_HOSTS ansible/site.yml -e @$OVN_DOCKER_VARS -e action=clean
popd
docker rmi ovn-scale-test-ovn
docker rmi ovn-scale-test-base
# Find the <none> image and delete it
docker rmi $(docker images | grep none | awk -F' +' '{print $3}')

popd
