#!/bin/bash -ex
#
#       <99-encrypt.sh>
#
#       Binds FDE key to the TPM
#
#       Copyright 2020 Dell Inc.
#           Mario Limonciello <Mario_Limonciello@Dell.com>
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.

# Detect if user selected encryption
if [ -f /etc/default/dell-recovery ]; then
    . /etc/default/dell-recovery
fi
if [ "$ENCRYPTION" = "true" ]; then
    # bind to the TPM (no PCR's; will be added later)
    clevis luks bind -d /dev/dell_lvm/rootfs -k /tmp/key tpm2 '{}'

    #remove our installer key
    cryptsetup luksRemoveKey /dev/dell_lvm/rootfs --key-file /tmp/key
fi