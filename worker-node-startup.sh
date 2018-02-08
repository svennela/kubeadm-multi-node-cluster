#! /bin/bash
set -e
set -x

sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF > kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo mv kubernetes.list /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y apt-transport-https
sudo apt-get install -y docker.io
sudo apt-get install -y kubelet kubeadm

sudo systemctl enable docker.service

cat <<EOF > 20-cloud-provider.conf
Environment="KUBELET_EXTRA_ARGS=--cloud-provider=gce"
EOF

sudo mv 20-cloud-provider.conf /etc/systemd/system/kubelet.service.d/
systemctl daemon-reload
systemctl restart kubelet



EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
KUBERNETES_VERSION=v1.9.0

  TOKEN="822515.f7abb6bd41368f03"
  MASTER_IP="10.128.0.4"

  sudo kubeadm join --token ${TOKEN} ${MASTER_IP}:6443 --discovery-token-unsafe-skip-ca-verification
  #kubeadm join --token 5b7804.ac568c8388123e58 10.128.0.3:6443 --discovery-token-ca-cert-hash sha256:201bb141b83cf4d9cac29a6f71d555a2759fcfe99dcc4047f91b7e5f760fe2cc
