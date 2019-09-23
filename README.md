# OpenStack Magnum Minikube driver

This is a Minikube Kubernetes driver for Magnum, which enables the deployment of
Minikube based Kubernetes cluster on Fedora Atomic.

Each cluster will consist of a single all-in-one node, and will have integration with OpenStack Keystone, Octavia, and Cinder enabled.

This has been tested with OpenStack Train and above.

## Installation

Install the driver on the same host, VPS, Container that has the magnum-api, and magnum-conductor running.

### 1. Install the Minikube K8s driver in Magnum

- To install the driver and run:
```
      make install
```

### 2. Enable driver in magnum.conf
The driver can be explicitly enabled with the following (although it should be automatically discovered anyway):
```
      enabled_definitions = ...,magnum_vm_atomic_minikube
```

With DevStack, this can be done with something like:
``` local.conf
...
[[post-config|$MAGNUM_CONF]]
[drivers]
send_cluster_metrics = False
verify_ca = false
disabled_drivers = k8s_coreos_v1,k8s_fedora_ironic_v1,mesos_ubuntu_v1,swarm_fedora_atomic_v1
[bay]
enabled_definitions=magnum_vm_atomic_k8s,magnum_vm_atomic_swarm,magnum_vm_atomic_minikube
...
```

### 3. Restart Magnum

  Both Magnum services has to restarted `magnum-api` and `magnum-conductor` with something like:

```
for i in `systemctl | grep magnum | awk '{print $1}'`; do systemctl restart $i; done
```

### 4. Install image/s

An image with the appropriate labels must be added to OpenStack so that Magnum can find it and
make the correct association with the minikube driver - use something like the following:

```
wget https://dl.fedoraproject.org/pub/alt/atomic/stable/Fedora-29-updates-20190708.0/AtomicHost/x86_64/images/Fedora-AtomicHost-29-20190708.0.x86_64.qcow2

# Minikube magnum driver hack - label the OS to match the driver
openstack image create \
    --container-format bare \
    --disk-format qcow2 \
    --public \
    --property os_distro=fedora-atomic-minikube \
    --property hw_rng_model=virtio \
    --file  Fedora-AtomicHost-29-20190708.0.x86_64.qcow2 \
    Fedora-AtomicHost-Minikube-29-20190708.0.x86_64
```

### 5. Create a Cluster Template

Once the driver is installed and the appropriate Glance image has been setup, a Cluster Template can be created:

```
openstack coe cluster template create minikube-template \
  --image Fedora-AtomicHost-Minikube-29-20190708.0.x86_64 \
  --docker-volume-size 25 \
  --docker-storage-driver overlay \
  --dns-nameserver 8.8.8.8 \
  --labels minikube_version=v1.4.0,etcd_version=v3.9,heat_container_agent_tag=train-dev,occm_container_infra_prefix=docker.io/piersharding/,cloud_provider_tag=latest \
  --keypair testkey \
  --external-network $(openstack network show public -f value -c id) \
  --flavor m1.medium --master-flavor m1.medium --network-driver calico \
  --coe kubernetes --master-lb-enabled --floating-ip-enabled \
  --volume-driver cinder
```

Note: that this cluster is using a specific image of openstack-cloud-controller-manager (https://github.com/kubernetes/cloud-provider-openstack).  
This has a modification to suppress filtering of master nodes by commenting out the condition here - https://github.com/kubernetes/kubernetes/blob/master/pkg/controller/service/service_controller.go#L645 .  This will hopefully be fixed in future releases as the checking is phased out by legacy (as per the code).
The interim image is here: https://hub.docker.com/r/piersharding/openstack-cloud-controller-manager .

### 5. Launch a Cluster

Now a cluster can be launched with the following:

```
openstack coe cluster create minikube --cluster-template minikube-template --timeout 25
```
