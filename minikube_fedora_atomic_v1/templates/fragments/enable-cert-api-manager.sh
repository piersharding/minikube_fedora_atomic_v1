#!/bin/sh

step="enable-cert-api-manager"
printf "Starting to run ${step}\n"

. /etc/sysconfig/heat-params

# if [ "$(echo $CERT_MANAGER_API | tr '[:upper:]' '[:lower:]')" != "false" ]; then
#     cert_dir=/var/lib/minikube/certs
#
#     echo -e "$CA_KEY" > ${cert_dir}/ca.key
#
#     chown kube.kube ${cert_dir}/ca.key
#     chmod 400 ${cert_dir}/ca.key
# fi

printf "Finished running ${step}\n"
