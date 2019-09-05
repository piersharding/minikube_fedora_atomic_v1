#!/usr/bin/env python
# Copyright (c) 2016 SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import setuptools

setuptools.setup(
    name="minikube_fedora_atomic_v1",
    version="1.0",
    packages=['minikube_fedora_atomic_v1'],
    package_data={
        'minikube_fedora_atomic_v1': ['templates/*', 'templates/fragments/*']
    },
    author="Piers Harding",
    author_email="piers@ompka.net",
    description="Magnum Minikube Kubernetes driver",
    license="Apache",
    keywords="magnum minikube driver",
    entry_points={
        'magnum.template_definitions': [
           'minikube_fedora_atomic_v1 = minikube_fedora_atomic_v1:AtomicMinikubeTemplateDefinition'
        ],
        'magnum.drivers': [
            'minikube_fedora_atomic_v1 = minikube_fedora_atomic_v1.driver:Driver'
        ]
    }
)
