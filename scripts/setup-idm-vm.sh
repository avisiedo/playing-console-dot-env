#!/bin/bash

source "scripts/helper.inc.sh"

set -e

# man virt-install
# man virsh
# https://www.techotopia.com/index.php/Creating_KVM_Virtual_Machines_on_RHEL_with_virt-install_and_virsh
# https://bobcares.com/blog/virsh-set-ip-address/


arch="$(print_arch)"
bridge_name="dataplane"
network_name="dataplane"
vm_name="idmserver"
vm_password="cloud123"
vm_mac="00:16:3e:42:7a:40"
vm_ip="192.168.35.12"

service_ipa_domain="cloud.testing"
service_ipa_password="Secret123"

# https://alt.fedoraproject.org/cloud/
# fedora_iso_url="https://download.fedoraproject.org/pub/fedora/linux/releases/35/Server/${arch}/iso/Fedora-Server-dvd-${arch}-35-1.2.iso"
fedora_qcow2_url="https://download.fedoraproject.org/pub/fedora/linux/releases/35/Cloud/${arch}/images/Fedora-Cloud-Base-35-1.2.${arch}.qcow2"
# rhel_iso_url="https://access.cdn.redhat.com/content/origin/files/sha256/1f/1f78e705cd1d8897a05afa060f77d81ed81ac141c2465d4763c0382aa96cadd0/rhel-8.5-x86_64-dvd.iso"

function idm_vm_download_iso {
    local output
    output="$PWD/.cache/${fedora_qcow2_url##*/}"
    # https://getfedora.org/es/server/download/
    msg_info "Downloading QCOW2 '${output}' from '${fedora_qcow2_url}'"
    [ -e "${output}" ] || curl -sLo "${output}" "${fedora_qcow2_url}"
}


function idm_vm_network_setup {
    local network_path=".cache/virsh-network-${network_name}.xml"
    msg_info "Setting up the network '${network_name}'"

    [ -e "${network_path}" ] \
    || cat > "${network_path}" <<EOF
<network>
  <name>${network_name}</name>
  <uuid>f1e5072e-ba22-11ec-a244-482ae3863d30</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='${bridge_name}' stp='on' delay='0' />
  <mac address='52:54:00:60:f8:6e'/>
  <ip address='192.168.35.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.35.2' end='192.168.35.254' />
      <host mac='${vm_mac}' name='virtual_machine' ip='${vm_ip}'/>
    </dhcp>
  </ip>
</network>
EOF
    sudo virsh net-info "${network_name}" &>/dev/null \
    || sudo virsh net-define "${network_path}"
    sudo virsh net-info "${network_name}" | grep "Active:" | grep -q yes \
    || {
        sudo virsh net-start "${network_name}"
        sudo virsh net-autostart "${network_name}"
    }
}
export -f idm_vm_network_setup

function idm_vm_install {
    # local iso_path="$PWD/.cache/${fedora_iso_url##*/}"
    local qcow2_path="$PWD/.cache/${fedora_qcow2_url##*/}"
    local cloud_init_path=".cache/cloudinit-user-data.yaml"
    sudo virsh desc idmserver &>/dev/null || {

        [ -e "${cloud_init_path}" ] || {
            # https://docs.fedoraproject.org/en-US/fedora-server/virtualization-vmcloud/#_preparing_user_data
            cat > "${cloud_init_path}" <<EOF
#cloud-config

# Setting hostname
preserve_hostname: False
hostname: idm
fqdn: idm.${service_ipa_domain}

# Set up root and fallback account including rsa key copied into this file
# (2) set up root and fallback account including rsa key copied into this file
users:
  - name: root
    ssh_authorized_keys:
      - $(grep ^ssh-rsa ~/.ssh/id_rsa.pub | head -n 1)

  - name: cloud
    groups: users,wheel
    ssh_pwauth: True
    ssh_authorized_keys:
      - $(grep ^ssh-rsa ~/.ssh/id_rsa.pub | head -n 1)

# Set up a first-time password for both accounts
chpasswd:
  list: |
    root:${vm_password}
    cloud:${vm_password}
  expire: False

# Install additional required packages
packages:
  - ipa-server
  - ipa-server-dns

# Perform a package upgrade
package_upgrade: true

# Several configuration commands are executed on first boot
runcmd:
  - growpart /dev/vda 1
  - resize2fs -p /dev/vda1
  - dnf -y module enable idm:DL1
  - dnf -y module install idm:DL1/dns
  - /usr/sbin/ipa-server-install \
      --unattended \
      --realm="${service_ipa_domain^^}" \
      --domain="${service_ipa_domain}" \
      --ds-password="${service_ipa_password}" \
      --admin-password="${service_ipa_password}" \
      --setup-dns \
      --auto-forwarders \
      --auto-reverse \
      --no-dnssec-validation \
      --no-host-dns \
      --no-ntp
  - systemctl disable cloud-init
  - reboot
EOF
        }

        sudo virt-install \
            --name "${vm_name}" \
            --noreboot \
            --memory 4096 \
            --disk "${qcow2_path}",format=qcow2,bus=virtio \
            --network network="${network_name}",model=virtio,mac="${vm_mac}" \
            --os-variant detect=on,name=fedora-unknown \
            --cpu host \
            --vcpus "4" \
            --tpm emulator \
            --rng builtin \
            --graphics none \
            --wait \
            --cloud-init user-data="${cloud_init_path}"
    }
}


function idm_vm_start {
    sudo virsh --connect qemu:///system start "${vm_name}"
}


idm_vm_download_iso
idm_vm_network_setup
idm_vm_install
idm_vm_start

msg_info "Now you can connect by 'ssh root@${vm_ip}'"
