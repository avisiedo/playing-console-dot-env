#!/bin/bash

source "scripts/helper.inc.sh"

network_name="dataplane"
vm_name="idmserver"

msg_info "Shutting down vm '${vm_name}'"
sudo virsh shutdown --domain "${vm_name}" --mode acpi
msg_info "Deleting vm '${vm_name}'"
sudo virsh undefine --domain "${vm_name}"
msg_info "Destroy network '${network_name}'"
sudo virsh net-destroy "${network_name}"
sudo virsh net-undefine --network "${network_name}"
msg_info "Deleting cloud-init configuration"
[ ! -e ".cache/cloudinit-user-data.yaml" ] || rm -vf ".cache/cloudinit-user-data.yaml"
msg_info "Deleting network configuration"
[ ! -e ".cache/virsh-network-dataplane.xml" ] || rm -vf ".cache/virsh-network-dataplane.xml"
msg_info "Deleting QCOW2 image"
[ ! -e ".cache/Fedora-Cloud-Base-35-1.2.x86_64.qcow2" ] || rm -vf ".cache/Fedora-Cloud-Base-35-1.2.x86_64.qcow2"
