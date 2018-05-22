#!/usr/bin/env bash
#
# Maintainer: Jorge Morales <jmorales@redhat.com>
#
# Package a box for uploading into Atlas as an OpenShift oc-cluster release
#
# $1 : Origin version
# $2 : Public host name

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__previous="$(cd $__dir/.. && pwd)"

help() {
   echo "This script will create a .box file ready to upload into Hashicorp's Atlas"
   echo ""
   echo " $0 <version>"
   echo ""
   echo "This will create a box named oc-cluster-version.box"
   echo ""
   echo "Version format: 1.1.0  1.1.6  1.2.1.1"
}

[ "$#" -lt 1 ] && help && exit 1

BOX_NAME="oc-cluster-crio"
ORIGIN_BRANCH="v$1"

pushd ${__previous}

# TODO: There's no checks, so it will run through the end even if it fails

# Execute the provisioning script
# vagrant up

# Before packaging we need to make sure that everything has been provisioned correcly and that provisioning has finished
# TODO:
# sleep 300 # For now, we'll wait 5 minutes

# Clean the box
vagrant ssh -c 'sudo /utils/pre-package.sh'

# vagrant package will halt the box for you
if [ -f release/${BOX_NAME}-${ORIGIN_BRANCH}.box ]; then
   echo "As there was a box already with that name, we will move it, appending timestamp"
   mv release/${BOX_NAME}-${ORIGIN_BRANCH}.box release/${BOX_NAME}-${ORIGIN_BRANCH}.box.$(date "+%Y%m%d%H%M%S")
fi
vagrant package --base oc-cluster-base --output release/${BOX_NAME}-${ORIGIN_BRANCH}.box --vagrantfile release/Vagrantfile

echo "If you want to try this locally, add it as: "
echo ""
echo "    vagrant box add --name jorgemoralespou/${BOX_NAME} release/${BOX_NAME}-${ORIGIN_BRANCH}.box"
echo ""
echo "otherwise, upload it to Atlas"

popd
