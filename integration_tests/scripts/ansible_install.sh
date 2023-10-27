# Update the package list
sudo apt-get update

# Install prerequisites
sudo apt-get install -y software-properties-common

# Add Ansible repository and key
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 93C4A3FD7BB9C367
sudo apt-add-repository 'deb http://ppa.launchpad.net/ansible/ansible-2.8/ubuntu bionic main'

# Update the package list again
sudo apt-get update

# Install Ansible
sudo apt-get install -y ansible
