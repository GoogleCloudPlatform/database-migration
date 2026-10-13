#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Configures a Reverse SSH Tunnel Bastion VM and corresponding firewall rules for DMS access.

export PROJECT_ID="your-project-id"
export ZONE="us-central1-a"
export NETWORK="default"
export SUBNET="default"
export VM_NAME="dms-bastion-vm"
export DB_PORT="5432" # Adjust to match your database port

# Create a firewall rule to allow IAP (Identity-Aware Proxy) SSH access
gcloud compute firewall-rules create allow-ssh-ingress-from-iap \
  --project="${PROJECT_ID}" \
  --direction=INGRESS \
  --action=allow \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20 \
  --network="${NETWORK}"

# Create a firewall rule to allow DMS to reach the Bastion VM on the tunneled port
gcloud compute firewall-rules create allow-dms-to-bastion \
  --project="${PROJECT_ID}" \
  --direction=INGRESS \
  --action=allow \
  --rules="tcp:${DB_PORT}" \
  --target-tags=dms-bastion \
  --network="${NETWORK}"

# Create the Bastion VM (No Public IP) with GatewayPorts enabled
gcloud compute instances create "${VM_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --machine-type=e2-micro \
  --network-interface="network-tier=PREMIUM,network=${NETWORK},subnet=${SUBNET},no-address" \
  --tags=dms-bastion \
  --metadata=enable-oslogin=true,startup-script='#! /bin/bash
sed -i "s/^#*GatewayPorts.*/GatewayPorts yes/" /etc/ssh/sshd_config
systemctl restart sshd'
