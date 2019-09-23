#!/bin/sh -x

. /etc/sysconfig/heat-params

echo "configuring kubernetes (master)"

ssh_cmd="ssh -F /srv/magnum/.ssh/config root@localhost"

if [ ! -z "$HTTP_PROXY" ]; then
    export HTTP_PROXY
fi

if [ ! -z "$HTTPS_PROXY" ]; then
    export HTTPS_PROXY
fi

if [ ! -z "$NO_PROXY" ]; then
    export NO_PROXY
fi

_prefix=${CONTAINER_INFRA_PREFIX:-docker.io/openstackmagnum/}

$ssh_cmd rm -rf /etc/cni/net.d/*
$ssh_cmd rm -rf /var/lib/cni/*
$ssh_cmd rm -rf /opt/cni/*
$ssh_cmd mkdir -p /opt/cni
$ssh_cmd mkdir -p /etc/cni/net.d/
# make it possible to create /data
$ssh_cmd 'chattr -i / && mkdir -p /data'
_addtl_mounts=',{"type":"bind","source":"/opt/cni","destination":"/opt/cni","options":["bind","rw","slave","mode=777"]},{"type":"bind","source":"/var/lib/docker","destination":"/var/lib/docker","options":["bind","rw","slave","mode=755"]},{"type":"bind","source":"/data","destination":"/data","options":["bind","rw","slave","mode=755"]}'

if [ "$NETWORK_DRIVER" = "calico" ]; then
    if [ "`systemctl status NetworkManager.service | grep -o "Active: active"`" = "Active: active" ]; then
        CALICO_NM=/etc/NetworkManager/conf.d/calico.conf
        [ -f ${CALICO_NM} ] || {
        echo "Writing File: $CALICO_NM"
        mkdir -p $(dirname ${CALICO_NM})
        cat << EOF > ${CALICO_NM}
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:tunl*
EOF
}
        systemctl restart NetworkManager
    fi
fi

########################
# dependent config

K8S_CONFIG_DIR=/var/lib/minikube/certs
$ssh_cmd mkdir -p $K8S_CONFIG_DIR
$ssh_cmd cp /etc/kubernetes/cloud-config $K8S_CONFIG_DIR/cloud-config

CERT_DIR=/etc/kubernetes/certs

# kube-proxy config
# PROXY_KUBECONFIG=/etc/kubernetes/proxy-kubeconfig.yaml
# cat > /etc/kubernetes/proxy << EOF
# KUBE_PROXY_ARGS="--kubeconfig=${PROXY_KUBECONFIG} --cluster-cidr=${PODS_NETWORK_CIDR}"
# EOF
#
# cat > ${PROXY_KUBECONFIG} << EOF
# apiVersion: v1
# clusters:
# - cluster:
#     certificate-authority: ${CERT_DIR}/ca.crt
#     server: http://127.0.0.1:8080
#   name: kubernetes
# contexts:
# - context:
#     cluster: kubernetes
#     user: kube-proxy
#   name: default
# current-context: default
# kind: Config
# preferences: {}
# users:
# - name: kube-proxy
#   user:
#     as-user-extra: {}
# EOF

# sed -i '
#     /^KUBE_ALLOW_PRIV=/ s/=.*/="--allow-privileged='"$KUBE_ALLOW_PRIV"'"/
#     /^KUBE_MASTER=/ s|=.*|="--master=http://127.0.0.1:8080"|
# ' /etc/kubernetes/config

# KUBE_API_ARGS="--runtime-config=api/all=true"
# KUBE_API_ARGS="$KUBE_API_ARGS --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP"
# KUBE_API_ARGS="$KUBE_API_ARGS $KUBEAPI_OPTIONS"
# if [ "$TLS_DISABLED" == "True" ]; then
#     KUBE_API_ADDRESS="--insecure-bind-address=0.0.0.0 --insecure-port=$KUBE_API_PORT"
# else
#     KUBE_API_ADDRESS="--bind-address=0.0.0.0 --secure-port=$KUBE_API_PORT"
#     # insecure port is used internaly
#     KUBE_API_ADDRESS="$KUBE_API_ADDRESS --insecure-bind-address=127.0.0.1 --insecure-port=8080"
#     KUBE_API_ARGS="$KUBE_API_ARGS --authorization-mode=Node,RBAC --tls-cert-file=$CERT_DIR/server.crt"
#     KUBE_API_ARGS="$KUBE_API_ARGS --tls-private-key-file=$CERT_DIR/server.key"
#     KUBE_API_ARGS="$KUBE_API_ARGS --client-ca-file=$CERT_DIR/ca.crt"
#     KUBE_API_ARGS="$KUBE_API_ARGS --service-account-key-file=${CERT_DIR}/service_account.key"
#     KUBE_API_ARGS="$KUBE_API_ARGS --kubelet-certificate-authority=${CERT_DIR}/ca.crt --kubelet-client-certificate=${CERT_DIR}/server.crt --kubelet-client-key=${CERT_DIR}/server.key --kubelet-https=true"
#     # Allow for metrics-server/aggregator communication
#     KUBE_API_ARGS="${KUBE_API_ARGS} \
#         --proxy-client-cert-file=${CERT_DIR}/server.crt \
#         --proxy-client-key-file=${CERT_DIR}/server.key \
#         --requestheader-allowed-names=front-proxy-client,kube,kubernetes \
#         --requestheader-client-ca-file=${CERT_DIR}/ca.crt \
#         --requestheader-extra-headers-prefix=X-Remote-Extra- \
#         --requestheader-group-headers=X-Remote-Group \
#         --requestheader-username-headers=X-Remote-User"
# fi

# KUBE_ADMISSION_CONTROL=""
# if [ -n "${ADMISSION_CONTROL_LIST}" ] && [ "${TLS_DISABLED}" == "False" ]; then
#     KUBE_ADMISSION_CONTROL="--admission-control=NodeRestriction,${ADMISSION_CONTROL_LIST}"
# fi
#
# if [ -n "$TRUST_ID" ] && [ "$(echo "${CLOUD_PROVIDER_ENABLED}" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
#     KUBE_API_ARGS="$KUBE_API_ARGS --cloud-provider=external"
# fi

# if [ "$KEYSTONE_AUTH_ENABLED" == "True" ]; then
    KEYSTONE_WEBHOOK_CONFIG=$K8S_CONFIG_DIR/keystone_webhook_config.yaml

    [ -f ${KEYSTONE_WEBHOOK_CONFIG} ] || {
echo "Writing File: $KEYSTONE_WEBHOOK_CONFIG"
mkdir -p $(dirname ${KEYSTONE_WEBHOOK_CONFIG})
cat << EOF > ${KEYSTONE_WEBHOOK_CONFIG}
---
apiVersion: v1
kind: Config
preferences: {}
clusters:
  - cluster:
      insecure-skip-tls-verify: true
      server: https://127.0.0.1:8443/webhook
    name: webhook
users:
  - name: webhook
contexts:
  - context:
      cluster: webhook
      user: webhook
    name: webhook
current-context: webhook
EOF
}
    # KUBE_API_ARGS="$KUBE_API_ARGS --authentication-token-webhook-config-file=/etc/kubernetes/keystone_webhook_config.yaml --authorization-webhook-config-file=/etc/kubernetes/keystone_webhook_config.yaml"
    # webhook_auth="--authorization-mode=Node,Webhook,RBAC"
    # KUBE_API_ARGS=${KUBE_API_ARGS/--authorization-mode=Node,RBAC/$webhook_auth}
# fi

# sed -i '
#     /^KUBE_API_ADDRESS=/ s/=.*/="'"${KUBE_API_ADDRESS}"'"/
#     /^KUBE_SERVICE_ADDRESSES=/ s|=.*|="--service-cluster-ip-range='"$PORTAL_NETWORK_CIDR"'"|
#     /^KUBE_API_ARGS=/ s|=.*|="'"${KUBE_API_ARGS}"'"|
#     /^KUBE_ETCD_SERVERS=/ s/=.*/="--etcd-servers=http:\/\/127.0.0.1:2379"/
#     /^KUBE_ADMISSION_CONTROL=/ s/=.*/="'"${KUBE_ADMISSION_CONTROL}"'"/
# ' /etc/kubernetes/apiserver


# # Add controller manager args
# KUBE_CONTROLLER_MANAGER_ARGS="--leader-elect=true"
# KUBE_CONTROLLER_MANAGER_ARGS="$KUBE_CONTROLLER_MANAGER_ARGS --cluster-name=${CLUSTER_UUID}"
# KUBE_CONTROLLER_MANAGER_ARGS="${KUBE_CONTROLLER_MANAGER_ARGS} --allocate-node-cidrs=true"
# KUBE_CONTROLLER_MANAGER_ARGS="${KUBE_CONTROLLER_MANAGER_ARGS} --cluster-cidr=${PODS_NETWORK_CIDR}"
# KUBE_CONTROLLER_MANAGER_ARGS="$KUBE_CONTROLLER_MANAGER_ARGS $KUBECONTROLLER_OPTIONS"
# if [ -n "${ADMISSION_CONTROL_LIST}" ] && [ "${TLS_DISABLED}" == "False" ]; then
#     KUBE_CONTROLLER_MANAGER_ARGS="$KUBE_CONTROLLER_MANAGER_ARGS --service-account-private-key-file=$CERT_DIR/service_account_private.key --root-ca-file=$CERT_DIR/ca.crt"
# fi
#
# if [ -n "$TRUST_ID" ] && [ "$(echo "${CLOUD_PROVIDER_ENABLED}" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
#     KUBE_CONTROLLER_MANAGER_ARGS="$KUBE_CONTROLLER_MANAGER_ARGS --cloud-provider=external"
#     KUBE_CONTROLLER_MANAGER_ARGS="$KUBE_CONTROLLER_MANAGER_ARGS --external-cloud-volume-plugin=openstack --cloud-config=/etc/kubernetes/cloud-config"
# fi
#
#
# if [ "$(echo $CERT_MANAGER_API | tr '[:upper:]' '[:lower:]')" = "true" ]; then
#     KUBE_CONTROLLER_MANAGER_ARGS="$KUBE_CONTROLLER_MANAGER_ARGS --cluster-signing-cert-file=$CERT_DIR/ca.crt --cluster-signing-key-file=$CERT_DIR/ca.key"
# fi

# sed -i '
#     /^KUBELET_ADDRESSES=/ s/=.*/="--machines='""'"/
#     /^KUBE_CONTROLLER_MANAGER_ARGS=/ s#\(KUBE_CONTROLLER_MANAGER_ARGS\).*#\1="'"${KUBE_CONTROLLER_MANAGER_ARGS}"'"#
# ' /etc/kubernetes/controller-manager

# sed -i '/^KUBE_SCHEDULER_ARGS=/ s/=.*/="--leader-elect=true"/' /etc/kubernetes/scheduler

$ssh_cmd mkdir -p /etc/kubernetes/manifests
# KUBELET_ARGS="--register-node=true --pod-manifest-path=/etc/kubernetes/manifests --cadvisor-port=0 --hostname-override=${INSTANCE_NAME}"
# KUBELET_ARGS="${KUBELET_ARGS} --pod-infra-container-image=${CONTAINER_INFRA_PREFIX:-gcr.io/google_containers/}pause:3.0"
# KUBELET_ARGS="${KUBELET_ARGS} --cluster_dns=${DNS_SERVICE_IP} --cluster_domain=${DNS_CLUSTER_DOMAIN}"

# might have to do something with this?
###KUBELET_ARGS="${KUBELET_ARGS} --volume-plugin-dir=/var/lib/kubelet/volumeplugins"
# KUBELET_ARGS="${KUBELET_ARGS} ${KUBELET_OPTIONS}"

# if [ -n "$TRUST_ID" ] && [ "$(echo "${CLOUD_PROVIDER_ENABLED}" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
#     KUBELET_ARGS="${KUBELET_ARGS} --cloud-provider=external"
# fi

# For using default log-driver, other options should be ignored
sed -i 's/\-\-log\-driver\=journald//g' /etc/sysconfig/docker

if [ -n "${INSECURE_REGISTRY_URL}" ]; then
    echo "INSECURE_REGISTRY='--insecure-registry ${INSECURE_REGISTRY_URL}'" >> /etc/sysconfig/docker
fi

# KUBELET_ARGS="${KUBELET_ARGS} --network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"


# might have to do something with these?
###KUBELET_ARGS="${KUBELET_ARGS} --register-with-taints=CriticalAddonsOnly=True:NoSchedule,dedicated=master:NoSchedule"
###KUBELET_ARGS="${KUBELET_ARGS} --node-labels=node-role.kubernetes.io/master=\"\""

# KUBELET_KUBECONFIG=/etc/kubernetes/kubelet-config.yaml
# cat << EOF >> ${KUBELET_KUBECONFIG}
# apiVersion: v1
# clusters:
# - cluster:
#     certificate-authority: ${CERT_DIR}/ca.crt
#     server: http://127.0.0.1:8080
#   name: kubernetes
# contexts:
# - context:
#     cluster: kubernetes
#     user: system:node:${INSTANCE_NAME}
#   name: default
# current-context: default
# kind: Config
# preferences: {}
# users:
# - name: system:node:${INSTANCE_NAME}
#   user:
#     as-user-extra: {}
#     client-certificate: ${CERT_DIR}/server.crt
#     client-key: ${CERT_DIR}/server.key
# EOF

# cat > /etc/kubernetes/get_require_kubeconfig.sh << EOF
# #!/bin/bash
#
# KUBE_VERSION=\$(kubelet --version | awk '{print \$2}')
# min_version=v1.8.0
# if [[ "\${min_version}" != \$(echo -e "\${min_version}\n\${KUBE_VERSION}" | sort -s -t. -k 1,1 -k 2,2n -k 3,3n | head -n1) && "\${KUBE_VERSION}" != "devel" ]]; then
#     echo "--require-kubeconfig"
# fi
# EOF
# chmod +x /etc/kubernetes/get_require_kubeconfig.sh

# KUBELET_ARGS="${KUBELET_ARGS} --client-ca-file=${CERT_DIR}/ca.crt --tls-cert-file=${CERT_DIR}/kubelet.crt --tls-private-key-file=${CERT_DIR}/kubelet.key --kubeconfig ${KUBELET_KUBECONFIG}"
#
# # specified cgroup driver
# KUBELET_ARGS="${KUBELET_ARGS} --cgroup-driver=${CGROUP_DRIVER}"

$ssh_cmd systemctl disable docker
if $ssh_cmd cat /usr/lib/systemd/system/docker.service | grep 'native.cgroupdriver'; then
        $ssh_cmd cp /usr/lib/systemd/system/docker.service /etc/systemd/system/
        sed -i "s/\(native.cgroupdriver=\)\w\+/\1$CGROUP_DRIVER/" \
                /etc/systemd/system/docker.service
else
        cat > /etc/systemd/system/docker.service.d/cgroupdriver.conf << EOF
ExecStart=---exec-opt native.cgroupdriver=$CGROUP_DRIVER
EOF

fi

$ssh_cmd systemctl daemon-reload
$ssh_cmd systemctl enable docker

# if [ -z "${KUBE_NODE_IP}" ]; then
#     KUBE_NODE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
# fi
#
# KUBELET_ARGS="${KUBELET_ARGS} --address=${KUBE_NODE_IP} --port=10250 --read-only-port=0 --anonymous-auth=false --authorization-mode=Webhook --authentication-token-webhook=true"

# sed -i '
# /^KUBELET_ADDRESS=/ s/=.*/="--address=${KUBE_NODE_IP}"/
# /^KUBELET_HOSTNAME=/ s/=.*/=""/
# /^KUBELET_ARGS=/ s|=.*|="'"\$(/etc/kubernetes/get_require_kubeconfig.sh) ${KUBELET_ARGS}"'"|
# ' /etc/kubernetes/kubelet


###########################


# generate sans
if [ -z "${KUBE_NODE_IP}" ]; then
    KUBE_NODE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
fi

sans="IP:${KUBE_NODE_IP}"

if [ -z "${KUBE_NODE_PUBLIC_IP}" ]; then
    KUBE_NODE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
fi

if [ -n "${KUBE_NODE_PUBLIC_IP}" ]; then
    sans="${sans},IP:${KUBE_NODE_PUBLIC_IP}"
fi

if [ "${KUBE_NODE_PUBLIC_IP}" != "${KUBE_API_PUBLIC_ADDRESS}" ] \
        && [ -n "${KUBE_API_PUBLIC_ADDRESS}" ]; then
    sans="${sans},IP:${KUBE_API_PUBLIC_ADDRESS}"
fi

if [ "${KUBE_NODE_IP}" != "${KUBE_API_PRIVATE_ADDRESS}" ] \
        && [ -n "${KUBE_API_PRIVATE_ADDRESS}" ]; then
    sans="${sans},IP:${KUBE_API_PRIVATE_ADDRESS}"
fi

MASTER_HOSTNAME=${MASTER_HOSTNAME:-}
if [ -n "${MASTER_HOSTNAME}" ]; then
    sans="${sans},DNS:${MASTER_HOSTNAME}"
fi

if [ -n "${ETCD_LB_VIP}" ]; then
    sans="${sans},IP:${ETCD_LB_VIP}"
fi

sans="${sans},IP:127.0.0.1"

KUBE_SERVICE_IP=$(echo $PORTAL_NETWORK_CIDR | awk 'BEGIN{FS="[./]"; OFS="."}{print $1,$2,$3,$4 + 1}')

sans="${sans},IP:${KUBE_SERVICE_IP},DNS:localhost,IP:10.96.0.1,IP:10.0.0.1"


# set environment
$ssh_cmd 'chattr -i /var/roothome && mkdir -p /var/roothome/.kube && chmod 0755 /var/roothome/.kube && touch /var/roothome/.kube/config && chmod 0640 /var/roothome/.kube/config'
$ssh_cmd 'mkdir -p /var/roothome/.minikube && chmod 0755 /var/roothome/.minikube'
mkdir -p /srv/magnum/kubernetes/
cat > /srv/magnum/kubernetes/install-kubernetes.sh <<EOF
#!/bin/bash -x

# settings required for calico
# [FATAL][400] int_dataplane.go 824: Kernel's RPF check is set to 'loose'.  This would allow endpoints to spoof their IP address.  Calico requires net.ipv4.conf.all.rp_filter to be set to 0 or 1. If you require loose RPF and you are not concerned about spoofing, this check can be disabled by setting the IgnoreLooseRPF configuration parameter to 'true'.
echo "net.ipv4.conf.all.rp_filter = 1" > /etc/sysctl.d/calico.conf
/usr/sbin/sysctl --system

# convert CA key from PKCS8 to PKCS1
openssl rsa -in  /etc/kubernetes/certs/ca-pkcs8.key -out  /root/.minikube/ca.key
chmod 400 /root/.minikube/ca.key
cp /etc/kubernetes/certs/ca.crt /root/.minikube/ca.crt

cd /tmp
# install minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64 && chmod +x minikube && sudo cp minikube /usr/local/bin/ && rm minikube
# install kubectl
curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && chmod +x kubectl && sudo cp kubectl /usr/local/bin/ && rm kubectl
# install jq
curl -Lo jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x jq && sudo cp jq /usr/local/bin/ && rm jq

# remount /usr so kubeadm can install
mount -o remount,rw /usr

# start minikube
export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export MINIKUBE_HOME=$HOME
export CHANGE_MINIKUBE_NONE_USER=true
export KUBECONFIG=$HOME/.kube/config

 minikube start --wait=true --apiserver-port=6443 \
                --extra-config=kubelet.network-plugin=cni \
                --extra-config=kubelet.resolv-conf=/etc/resolv.conf \
                --extra-config=kubelet.cgroup-driver=$CGROUP_DRIVER \
                --apiserver-ips=${KUBE_NODE_IP} \
                --apiserver-ips=${KUBE_NODE_PUBLIC_IP} \
                --apiserver-ips=${KUBE_API_PUBLIC_ADDRESS} \
                --apiserver-ips=${KUBE_API_PRIVATE_ADDRESS} \
                --apiserver-ips=127.0.0.1 \
                --apiserver-ips=10.0.0.1 \
                --apiserver-ips=10.96.0.1 \
                --apiserver-names=localhost \
                --extra-config=kubeadm.pod-network-cidr=10.200.0.0/16 \
                --network-plugin=cni \
                --extra-config=apiserver.cloud-provider=external \
                --extra-config=apiserver.authorization-mode=Node,Webhook,RBAC \
                --extra-config=apiserver.authentication-token-webhook-config-file=$KEYSTONE_WEBHOOK_CONFIG \
                --extra-config=apiserver.authorization-webhook-config-file=$KEYSTONE_WEBHOOK_CONFIG \
                --extra-config=apiserver.insecure-bind-address=127.0.0.1 \
                --extra-config=apiserver.insecure-port=8080 \
                --extra-config=controller-manager.cloud-provider=external \
                --vm-driver=none

                # --extra-config=kubelet.cloud-provider=external
                # --extra-config=controller-manager.external-cloud-volume-plugin=openstack
                # --extra-config=controller-manager.cloud-config=$K8S_CONFIG_DIR/cloud-config

minikube status

# install etcd for calico
# this version is broken with apiVersion and selector
# kubectl apply -f https://docs.projectcalico.org/$ETCD_VERSION/getting-started/kubernetes/installation/hosted/etcd.yaml && sleep 5
kubectl apply -f /srv/magnum/kubernetes/etcd.yaml && sleep 5

ETCD_ENDPOINT=\`kubectl get service -o json --namespace=kube-system calico-etcd | jq  -r .spec.clusterIP\`
# install calico
curl -Lo /tmp/calico.yaml https://docs.projectcalico.org/$ETCD_VERSION/getting-started/kubernetes/installation/hosted/calico.yaml
sed -i "s/<ETCD_IP>:<ETCD_PORT>/\$ETCD_ENDPOINT:6666/" calico.yaml
kubectl apply -f /tmp/calico.yaml && rm -f /tmp/calico.yaml

# enable addons
#minikube addons enable ingress

# create the cloud config secret required by the CSI driver
kubectl create secret -n kube-system generic cloud-config --from-literal=cloud.conf="$(cat /etc/kubernetes/cloud-config-occm)" --dry-run -o yaml > /etc/kubernetes/cloud-config-secret.yaml
kubectl -f /etc/kubernetes/cloud-config-secret.yaml apply

# remove master label
# echo "labels before:"
# kubectl get nodes --show-labels
# kubectl label node minikube node-role.kubernetes.io/master-
# echo "labels after:"
# kubectl get nodes --show-labels

# distribute config
mkdir -p /home/fedora/.kube
kubectl config view --flatten > /home/fedora/.kube/config
chown -R fedora:fedora /home/fedora/.kube


#atomic install --storage ostree --system --set=ADDTL_MOUNTS='${_addtl_mounts}' --system-package=no --name=kubelet ${_prefix}kubernetes-kubelet:${KUBE_TAG}
#atomic install --storage ostree --system --system-package=no --name=kube-apiserver ${_prefix}kubernetes-apiserver:${KUBE_TAG}
EOF
chmod +x /srv/magnum/kubernetes/install-kubernetes.sh

# etcd yaml is broken so we add our own here
cat >/srv/magnum/kubernetes/etcd.yaml << EOF
# based on v3.9 - fixes apiVersion and selector
# This manifest installs the Calico etcd on the kubeadm master.  This uses a DaemonSet
# to force it to run on the master even when the master isn't schedulable, and uses
# nodeSelector to ensure it only runs on the master.
apiVersion: apps/v1
kind: DaemonSet
metadata:
 name: calico-etcd
 namespace: kube-system
 labels:
   k8s-app: calico-etcd
spec:
 selector:
   matchLabels:
     k8s-app: calico-etcd
 template:
   metadata:
     labels:
       k8s-app: calico-etcd
     annotations:
       # Mark this pod as a critical add-on; when enabled, the critical add-on scheduler
       # reserves resources for critical add-on pods so that they can be rescheduled after
       # a failure.  This annotation works in tandem with the toleration below.
       scheduler.alpha.kubernetes.io/critical-pod: ''
   spec:
     tolerations:
       # This taint is set by all kubelets running `--cloud-provider=external`
       # so we should tolerate it to schedule the Calico pods
       - key: node.cloudprovider.kubernetes.io/uninitialized
         value: "true"
         effect: NoSchedule
       # Allow this pod to run on the master.
       - key: node-role.kubernetes.io/master
         effect: NoSchedule
       # Allow this pod to be rescheduled while the node is in "critical add-ons only" mode.
       # This, along with the annotation above marks this pod as a critical add-on.
       - key: CriticalAddonsOnly
         operator: Exists
     # Only run this pod on the master.
     nodeSelector:
       node-role.kubernetes.io/master: ""
     hostNetwork: true
     containers:
       - name: calico-etcd
         image: quay.io/coreos/etcd:v3.3.9
         env:
           - name: CALICO_ETCD_IP
             valueFrom:
               fieldRef:
                 fieldPath: status.podIP
         command:
         - /usr/local/bin/etcd
         args:
         - --name=calico
         - --data-dir=/var/etcd/calico-data
         - --advertise-client-urls=http://$(CALICO_ETCD_IP):6666
         - --listen-client-urls=http://0.0.0.0:6666
         - --listen-peer-urls=http://0.0.0.0:6667
         - --auto-compaction-retention=1
         volumeMounts:
           - name: var-etcd
             mountPath: /var/etcd
     volumes:
       - name: var-etcd
         hostPath:
           path: /var/etcd

---
# This manifest installs the Service which gets traffic to the Calico
# etcd.
apiVersion: v1
kind: Service
metadata:
 labels:
   k8s-app: calico-etcd
 name: calico-etcd
 namespace: kube-system
spec:
 # Select the calico-etcd pod running on the master.
 selector:
   k8s-app: calico-etcd
 # This ClusterIP needs to be known in advance, since we cannot rely
 # on DNS to get access to etcd.
 clusterIP: 10.96.232.136
 ports:
   - port: 6666
EOF

$ssh_cmd "/srv/magnum/kubernetes/install-kubernetes.sh"
