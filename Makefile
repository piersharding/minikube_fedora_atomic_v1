PYTHON ?= python

.PHONY = build install clean

clean:
	rm -rf build minikube_fedora_atomic_v1.egg-info dist

build:
	$(PYTHON) setup.py build

install: build
	$(PYTHON) setup.py install
