# kubeadm: Multi Node Kubernetes Cluster


Create a master compute instance:


```bash
gcloud compute instances create kubeadm-master-node --can-ip-forward --image-family ubuntu-1704 --image-project ubuntu-os-cloud --machine-type n1-standard-2 --metadata kubernetes-version=stable-1.8 --metadata-from-file startup-script=master-node-startup.sh --tags kubeadm-master-node --scopes cloud-platform,logging-write
```

gcloud compute instances create kubeadm-master-node \
  --can-ip-forward \
  --image-family ubuntu-1710 \
  --image-project ubuntu-os-cloud \
  --machine-type n1-standard-1 \
  --metadata kubernetes-version=stable-1.9 \
  --metadata-from-file startup-script=master-node-startup.sh \
  --tags kubeadm-master-node \
  --scopes cloud-platform,logging-write



Starting in v1.9 you should create and use a Discovery Token CA Cert Hash created from the master to ensure the node joins the cluster in a secure manner. Run this on the master node or wherever you have a copy of the CA file. You will get a long string as output.

openssl x509 -pubkey \
        -in /etc/kubernetes/pki/ca.crt | openssl rsa \
        -pubin -outform der 2>/dev/null | openssl dgst \
        -sha256 -hex | sed 's/^.* //'

copy the sha256 into MASTERSHA.

Once you create master node, we need TOKEN and MASTER_IP from above and update worker-node-startup.sh, then magic happens.
ssh into kubeadm-master-node and type below command for to get kubeadm TOKEN

sudo kubeadm token list

copy the token and master node ip into TOKEN and MASTER_IP.


Enable secure remote access to the Kubernetes API server:


```
gcloud compute firewall-rules create default-allow-kubeadm-master-node \
  --allow tcp:6443 \
  --target-tags kubeadm-master-node \
  --source-ranges 0.0.0.0/0
```

```
gcloud compute firewall-rules create default-allow-kubeadm-worker-node \
  --allow tcp:6443 \
  --target-tags kubeadm-worker-node \
  --source-ranges 0.0.0.0/0
```

Create a work compute instances:

for i in 1; do
  gcloud compute instances create kubeadm-worker-node-${i} \
    --async \
    --boot-disk-size 50GB \
    --can-ip-forward \
    --image-family ubuntu-1604-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --metadata kubernetes-version=stable-1.9 \
    --metadata-from-file startup-script=worker-node-startup.sh \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --tags kubeadm-worker-node
done




Fetch the client kubernetes configuration file:

```
gcloud compute scp kubeadm-master-node:/etc/kubernetes/admin.conf kubeadm-master-node.conf
```

> It may take a few minutes for the cluster to finish bootstrapping and the client config to become readable.

Set the `KUBECONFIG` env var to point to the `kubeadm-master-node.conf` kubeconfig:

```
export KUBECONFIG=$(PWD)/kubeadm-master-node.conf
```

Set the `kubeadm-master-node-cluster` kubeconfig server address to the public IP address:

```
kubectl config set-cluster kubernetes \
  --kubeconfig kubeadm-master-node.conf \
  --server https://$(gcloud compute instances describe kubeadm-master-node \
     --format='value(networkInterfaces.accessConfigs[0].natIP)'):6443
```
Or

```
sudo cp kubeadm-master-node.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/kubeadm-master-node.conf
export KUBECONFIG=$HOME/kubeadm-master-node.conf
```


## Verification

List the Kubernetes nodes:

```
kubectl get nodes
```
```
NAME                          STATUS    ROLES     AGE       VERSION
kubeadm-master-node-cluster   Ready     master    35m       v1.8.0
```

The node version reflects the `kubelet` version, therefore it might be different
than the `kubernetes-version` specified above.

Find out Kubernetes API server version:

```
kubectl version --short
```
```
Client Version: v1.7.5
Server Version: v1.9.0
```

Create a nginx deployment:

```
kubectl run nginx --image nginx:1.13 --port 80
```

Expose the nginx deployment:

```
kubectl expose deployment nginx --type LoadBalancer
```

## Cleanup

```
gcloud compute instances delete kubeadm-master-node-cluster
gcloud compute instances delete kubeadm-worker-node-1
gcloud compute instances delete kubeadm-worker-node-2
```

```
gcloud compute firewall-rules delete default-allow-kubeadm-master-node-cluster
```

```
rm kubeadm-master-node.conf
```
