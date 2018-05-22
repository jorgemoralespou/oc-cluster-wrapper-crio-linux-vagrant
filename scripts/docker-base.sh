#!/usr/bin/env bash
#
# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"

##################################################
#
# Setting sane defaults, just in case
: ${__OS_JOURNAL_SIZE:="100M"}
: ${__OS_DOCKER_STORAGE_SIZE:="30G"}

# This script must be run as root
must_run_as_root(){
   [ "$UID" -ne 0 ] && echo "To run this script you need root permissions (either root or sudo)" && exit 1
}

#################################################################
OS-Setup(){
      dnf update -y
      # Install additional packages
      dnf install -y docker git bind-utils bash-completion htop; yum clean all

      # Install jq for json parsing
      curl --fail --silent --location --retry 3 \
         https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
         -o /usr/local/bin/jq \
         && chmod 755 /usr/local/bin/jq

      # Fail if commands have not been installed
      [ "$(which docker)" = "" ] && echo "[ERROR] Docker is not properly installed" && exit 1
      [ "$(which git)" = "" ] && echo "[ERROR] Git is not properly installed" && exit 1
      [ ! -f /usr/local/bin/jq ] && echo "[ERROR] jq is not properly installed" && exit 1

      # Update journal size so it doesn't grow forever
      sed -i -e "s/.*SystemMaxUse.*/SystemMaxUse=${__OS_JOURNAL_SIZE}/" /etc/systemd/journald.conf
      systemctl restart systemd-journald
}

DOCKER-Setup(){
      systemctl stop docker

      # Add docker capabilities to vagrant user
      groupadd docker
      usermod -aG docker vagrant

      # TODO: Find why Origin does not start in enforcing
      sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
      sudo setenforce 0
      echo "[WARN] Set SELinux to permissive for now"

      ##  Enable the internal registry and configure the Docker to allow pushing to internal OpenShift registry
      echo "[INFO] Configuring Docker for Red Hat registry and else ..."

      # These lines are changed for Fedora 26+
      # sed -i -e "s/^.*ADD_REGISTRY=.*/ADD_REGISTRY='--add-registry registry\.access\.redhat\.com'/" /etc/sysconfig/docker
      # sed -i -e "s/^.*OPTIONS=.*/OPTIONS='--selinux-enabled --storage-opt dm\.loopdatasize=${__OS_DOCKER_STORAGE_SIZE}'/" /etc/sysconfig/docker
      cp /etc/containers/registries.conf /etc/containers/registries.conf.ori
#      cat /etc/containers/registries.conf.ori | tr '\n' '\r' | sed -e "s/#insecure_registries:\r#  - \r/insecure_registries:\r  - 172\.30\.0\.0\/16\r/" | tr '\r' '\n' > /etc/containers/registries.conf
      cat /etc/containers/registries.conf.ori | tr '\n' '\$' | sed -e "s/\[registries\.insecure\]\$registries = \[\]/\[registries\.insecure\]\$registries = \[\'172\.30\.0\.0\/16\'\]\$/"  | tr '\$' '\n' > /etc/containers/registries.conf
      ## Disable firewall
      systemctl start docker; systemctl enable docker

      # docker network inspect -f "{{range .IPAM.Config }}{{ .Subnet }}{{end}}" bridge
#      echo "[INFO] Enabling and configuring firewalld"
#      dnf install -y firewalld
#      systemctl start firewalld; systemctl enable firewalld 
#      firewall-cmd --permanent --zone public --add-port 80/tcp
#      firewall-cmd --permanent --zone public --add-port 443/tcp
#      firewall-cmd --permanent --zone public --add-port 8443/tcp
#      firewall-cmd --permanent --new-zone dockerc
#      firewall-cmd --permanent --zone dockerc --add-source 172.17.0.0/16
#      firewall-cmd --permanent --zone dockerc --add-port 8080/tcp
#      firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
#      firewall-cmd --permanent --zone dockerc --add-port 53/udp
#      firewall-cmd --permanent --zone dockerc --add-port 8053/udp
#      firewall-cmd --reload
      echo "done"
}

must_run_as_root

OS-Setup
DOCKER-Setup
