#!/usr/bin/env bash
#
# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"

##################################################
#
# Setting sane defaults, just in case
# : ${__OS_VERSION:="v3.9.0"}

# This script must be run as root
must_run_as_root(){
   [ "$UID" -ne 0 ] && echo "To run this script you need root permissions (either root or sudo)" && exit 1
}

#################################################################
CRIO-1-10-Setup(){
  sudo dnf install -y cri-o cri-tools podman buildah skopeo
}

CRIO-1-9-Setup(){
  # Install crio 1.9
  sudo dnf install -y podman buildah skopeo go

  # Install cri-o 1.9 from koji: https://koji.fedoraproject.org/koji/buildinfo?buildID=1057722
  #
  curl -kL https://kojipkgs.fedoraproject.org//packages/cri-o/1.9.10/1.git8723732.fc28/x86_64/conmon-1.9.10-1.git8723732.fc28.x86_64.rpm -O  
  curl -lL https://kojipkgs.fedoraproject.org//packages/cri-o/1.9.10/1.git8723732.fc28/x86_64/cri-o-1.9.10-1.git8723732.fc28.x86_64.rpm -O
  dnf install -y conmon*.rpm cri-o*.rpm
 
  # Build cri-tools: https://github.com/kubernetes-incubator/cri-o/blob/release-1.9/Dockerfile#L99-L108
  #
  export CRICTL_COMMIT=b42fc3f364dd48f649d55926c34492beeb9b2e99
  export GOPATH="$(mktemp -d)" \
     && git clone https://github.com/kubernetes-incubator/cri-tools.git "$GOPATH/src/github.com/kubernetes-incubator/cri-tools" \
     && cd "$GOPATH/src/github.com/kubernetes-incubator/cri-tools" \
     && git checkout -q "$CRICTL_COMMIT" \
     && go install github.com/kubernetes-incubator/cri-tools/cmd/crictl \
     && cp "$GOPATH"/bin/crictl /usr/bin/ \
     && rm -rf "$GOPATH"

  # Configure /etc/crio/crio.conf
  # Add insecure registries, after line: insecure_registries = [
  sed -i '/^insecure_registries = \[/a \  "172\.30\.0\.0\/16"' /etc/crio/crio.conf
  # Add secure registries, after line: registries = [
  sed -i '/^registries = \[/a \  "docker\.io", "quay\.io", "registry\.access\.redhat\.com"' /etc/crio/crio.conf

  # Configure /etc/crictl.yaml with --runtime-endpoint and --image-endpoint = unix:///var/run/crio/crio.sock
cat <<- EOF > /etc/crictl.yaml
runtime-endpoint: /var/run/crio/crio.sock
image-endpoint: /var/run/crio/crio.sock
timeout: 2
debug: false
EOF

  systemctl enable crio
  systemctl start crio

  echo "done"
}

must_run_as_root

CRIO-1-9-Setup
