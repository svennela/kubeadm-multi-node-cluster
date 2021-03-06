#! /bin/bash
set -e
set -x

sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF > kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo mv kubernetes.list /etc/apt/sources.list.d/kubernetes.list
KUBE_VERSION=1.11.2-00
sudo apt-get update
sudo apt-get install -y apt-transport-https
sudo apt-get install -y docker.io
sudo apt-get install -y kubeadm=${KUBE_VERSION} kubelet=${KUBE_VERSION}
sudo systemctl enable docker.service

cat <<EOF > 20-cloud-provider.conf
Environment="KUBELET_EXTRA_ARGS=--cloud-provider=gce"
EOF

sudo mv 20-cloud-provider.conf /etc/systemd/system/kubelet.service.d/
systemctl daemon-reload
systemctl restart kubelet
systemctl restart docker

EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
KUBERNETES_VERSION=v1.11.2

cat <<EOF > kubeadm.conf
kind: MasterConfiguration
apiVersion: kubeadm.k8s.io/v1alpha1
apiServerCertSANs:
  - 10.96.0.1
  - ${EXTERNAL_IP}
  - ${INTERNAL_IP}
controllerManagerExtraArgs:
  horizontal-pod-autoscaler-use-rest-clients: "true"
  horizontal-pod-autoscaler-sync-period: "10s"
  node-monitor-grace-period: "10s"
apiServerExtraArgs:
  feature-gates: AllAlpha=true
  runtime-config: api/all
cloudProvider: gce
kubernetesVersion: ${KUBERNETES_VERSION}
networking:
  podSubnet: 192.168.0.0/16
EOF
cp kubeadm.conf /etc/kubernetes/kubeadm.conf
sudo kubeadm init --skip-preflight-checks --config=kubeadm.conf

sudo chmod 644 /etc/kubernetes/admin.conf

kubectl taint nodes --all node-role.kubernetes.io/master- \
  --kubeconfig /etc/kubernetes/admin.conf

kubectl apply \
  -f http://docs.projectcalico.org/v2.4/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml \
  --kubeconfig /etc/kubernetes/admin.conf
