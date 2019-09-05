#!/bin/sh

step="kube-nginx-ingress"
printf "Starting to run ${step}\n"

ssh_cmd="ssh -F /srv/magnum/.ssh/config root@localhost"

. /etc/sysconfig/heat-params

set -x

echo "Waiting for Kubernetes API..."
until  [ "ok" = "$(curl --silent http://127.0.0.1:8080/healthz)" ]
do
    sleep 5
done

# I0830 02:47:01.229616       1 event.go:209] Event(v1.ObjectReference{Kind:"Service", Namespace:"ingress-nginx", Name:"ingress-nginx", UID:"9db01ecc-9994-4ffc-829c-0e2ec9d3cdad", APIVersion:"v1", ResourceVersion:"2940", FieldPath:""}): type: 'Warning' reason: 'CreatingLoadBalancerFailed' Error creating load balancer (will retry): failed to ensure load balancer for service ingress-nginx/ingress-nginx: there are no available nodes for LoadBalancer service ingress-nginx/ingress-nginx
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
# curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/cloud-generic.yaml | grep -v externalTrafficPolicy | kubectl apply -f -

echo "Kubernetes API is up ..."

# enable addons
$ssh_cmd /usr/local/bin/minikube addons enable ingress
sleep 1
echo "minikube addons state:"
$ssh_cmd /usr/local/bin/minikube addons list

printf "Finished running ${step}\n"
