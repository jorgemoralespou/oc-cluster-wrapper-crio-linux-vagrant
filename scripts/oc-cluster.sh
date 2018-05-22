#!/usr/bin/env bash
#
# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"

##################################################
#
# Setting sane defaults, just in case
: ${__OS_VERSION:="v3.9.0"}

# This script must be run as root
must_run_as_root(){
   [ "$UID" -ne 0 ] && echo "To run this script you need root permissions (either root or sudo)" && exit 1
}

#################################################################
OC-CLUSTER-Setup(){
  # Validate that options are ok, and that requirements are met
  # Download release info
  curl -skL https://api.github.com/repos/openshift/origin/releases/tags/${__OS_VERSION} -o /tmp/origin-release.json
  if [[  $(cat /tmp/origin-release.json | /usr/local/bin/jq '.message') == "\"Not Found\"" ]]
  then
    echo "[ERROR] Release ${__OS_VERSION} not found. Instllation will exit now" && exit 1
  else
    echo "[INFO] Release found"
  fi
  # Download the release and extract
  cat /tmp/origin-release.json | /usr/local/bin/jq '.assets[].browser_download_url' | grep "client-tools" | grep "linux-64bit" | sed -e 's/^"//'  -e 's/"$//' | xargs curl -kL -o /tmp/origin.tar.gz
  [ ! -f /tmp/origin.tar.gz ] && "[ERROR] File not found" && exit 1
  
  mkdir -p /tmp/origin
  tar -xvzf /tmp/origin.tar.gz -C /tmp/origin

  # We use for images the same version as for release
  export __VERSION=${__OS_VERSION}

  # We copy the binaries into the /usr/local/bin
  __dir=$(find /tmp/origin -name "*origin-*")
  mv $__dir/oc /usr/local/bin
  chmod 755 /usr/local/bin/oc
  chown vagrant:vagrant /usr/local/bin/oc
  # Add bash completion
  /usr/local/bin/oc completion bash > /etc/bash_completion.d/oc.bash
  chown vagrant:vagrant /etc/bash_completion.d/oc.bash
}


OC-CLUTER-WRAPPER-Setup(){
  [ -d /home/vagrant/oc-cluster-wrapper ] && rm -rf /home/vagrant/oc-cluster-wrapper && echo "[INFO] Old clone of cluster-wrapper deleted" && sleep 1
  git clone https://github.com/openshift-evangelists/oc-cluster-wrapper /home/vagrant/oc-cluster-wrapper
  chown -R vagrant:vagrant /home/vagrant/oc-cluster-wrapper

  echo "[INFO] oc-cluster wrapper cloned"

  # Backup /home/vagrant/.bash_profile
  [ "`alias | grep cp`" != "" ] && unalias cp || echo "cp unaliased"
  if [ ! -f /home/vagrant/.bash_profile.ori ]
  then
    echo "cp -pf /home/vagrant/.bash_profile /home/vagrant/.bash_profile.ori"
    cp -pf /home/vagrant/.bash_profile /home/vagrant/.bash_profile.ori
    echo "done"
  else
    echo "cp -pf /home/vagrant/.bash_profile.ori /home/vagrant/.bash_profile"
    cp -pf /home/vagrant/.bash_profile.ori /home/vagrant/.bash_profile
    echo "done"
  fi

  echo "[INFO] Adding path"
  echo 'PATH=$HOME/oc-cluster-wrapper:$PATH' >> /home/vagrant/.bash_profile
  echo 'export PATH' >> /home/vagrant/.bash_profile
  echo 'export OC_CLUSTER_PUBLIC_HOSTNAME=10.4.4.4' >> /home/vagrant/.bash_profile
  echo "done"

  echo "[INFO] Configuring oc-cluster completion"
  OC_BINARY=/usr/local/bin/oc /home/vagrant/oc-cluster-wrapper/oc-cluster completion bash > /etc/bash_completion.d/oc-cluster.bash
  chown vagrant:vagrant /etc/bash_completion.d/oc-cluster.bash
  echo "done"
}

must_run_as_root

OC-CLUSTER-Setup
OC-CLUTER-WRAPPER-Setup
