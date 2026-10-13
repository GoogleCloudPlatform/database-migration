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

# Example script to configure a Cloud Router and Cloud NAT using gcloud.

export PROJECT_ID="your-project-id"
export REGION="your-region"
export NETWORK="your-vpc-network"
export SUBNET="your-subnet-name"
export ROUTER_NAME="dms-cloud-router"
export NAT_NAME="dms-cloud-nat"
export NAT_IP_NAME="dms-nat-ip"

# 1. Create a Cloud Router
gcloud compute routers create "${ROUTER_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --network="${NETWORK}"

# 2. Allocate a static external IP address (to allowlist on the source database)
gcloud compute addresses create "${NAT_IP_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}"

# 3. Create a Cloud NAT gateway using the static IP
# This configuration only applies to the specific subnet where the Network Attachment will be deployed.
gcloud compute routers nats create "${NAT_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --router="${ROUTER_NAME}" \
    --nat-external-ip-pool="${NAT_IP_NAME}" \
    --nat-custom-subnet-ip-ranges="${SUBNET}"
