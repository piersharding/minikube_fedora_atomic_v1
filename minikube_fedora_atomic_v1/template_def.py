# Copyright 2016 Rackspace Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import os

from oslo_utils import strutils
import magnum.conf
from magnum.drivers.heat import k8s_fedora_template_def as kftd
from magnum.conductor.handlers.common import cert_manager
from magnum.common.x509 import operations as x509
from magnum.common import keystone
import six
from oslo_log import log as logging

LOG = logging.getLogger(__name__)

CONF = magnum.conf.CONF
COMMON_ENV_PATH = "../../../magnum/drivers/common/templates/environments/"


class AtomicMinikubeTemplateDefinition(kftd.K8sFedoraTemplateDefinition):
    """Minikube template for a Fedora Atomic VM."""

    def get_params(self, context, cluster_template, cluster, **kwargs):
        LOG.info("########## get_params")
        extra_params = kwargs.pop('extra_params', {})

        label_list = ['minikube_version',
                      'kubectl_version',
                      'occm_container_infra_prefix',
                      'etcd_version']

        for label in label_list:
            label_value = cluster.labels.get(label)
            if label_value:
                extra_params[label] = label_value

        # handover the ca_key
        ca_cert = cert_manager.get_cluster_ca_certificate(cluster, context)
        if six.PY3 and isinstance(ca_cert.get_private_key_passphrase(),
                                  six.text_type):
            extra_params['ca_key'] = x509.decrypt_key(
                ca_cert.get_private_key(),
                ca_cert.get_private_key_passphrase().encode()
            ).decode().replace("\n", "\\n")
        else:
            extra_params['ca_key'] = x509.decrypt_key(
                ca_cert.get_private_key(),
                ca_cert.get_private_key_passphrase()).replace("\n", "\\n")

        return super(AtomicMinikubeTemplateDefinition,
                     self).get_params(context, cluster_template, cluster,
                                      extra_params=extra_params,
                                      **kwargs)

    def get_env_files(self, cluster_template, cluster):
        LOG.info("########## get_env_files")
        env_files = []

        if (cluster.fixed_network or cluster_template.fixed_network):
            env_files.append(COMMON_ENV_PATH + 'no_private_network.yaml')
        else:
            env_files.append(COMMON_ENV_PATH + 'with_private_network.yaml')

        # if int(cluster_template.labels.get('etcd_volume_size', 0)) < 1:
        env_files.append(COMMON_ENV_PATH + 'no_etcd_volume.yaml')
        # else:
        #     env_files.append(COMMON_ENV_PATH + 'with_etcd_volume.yaml')

        if cluster.docker_volume_size is None:
            env_files.append(COMMON_ENV_PATH + 'no_volume.yaml')
        else:
            env_files.append(COMMON_ENV_PATH + 'with_volume.yaml')

        if cluster_template.master_lb_enabled:
            if keystone.is_octavia_enabled():
                env_files.append(COMMON_ENV_PATH + 'with_master_lb_octavia.yaml')
            else:
                env_files.append(COMMON_ENV_PATH + 'with_master_lb.yaml')
        else:
            env_files.append(COMMON_ENV_PATH + 'no_master_lb.yaml')

        lb_fip_enabled = cluster.labels.get(
            "master_lb_floating_ip_enabled",
            cluster_template.floating_ip_enabled
        )
        master_lb_fip_enabled = strutils.bool_from_string(lb_fip_enabled)

        if cluster.floating_ip_enabled:
            env_files.append(COMMON_ENV_PATH + 'enable_floating_ip.yaml')
        else:
            env_files.append(COMMON_ENV_PATH + 'disable_floating_ip.yaml')

        if cluster_template.master_lb_enabled and master_lb_fip_enabled:
            env_files.append(COMMON_ENV_PATH + 'enable_lb_floating_ip.yaml')
        else:
            env_files.append(COMMON_ENV_PATH + 'disable_lb_floating_ip.yaml')

        return env_files

    @property
    def driver_module_path(self):
        return __name__[:__name__.rindex('.')]

    @property
    def template_path(self):
        LOG.info("########## template_path")
        return os.path.join(os.path.dirname(os.path.realpath(__file__)),
                            'templates/kubecluster.yaml')
