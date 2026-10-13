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

# Creates and runs a Network Intelligence Center Connectivity Test to verify
# connectivity from a Network Attachment to a source database.

export PROJECT_ID="your-project-id"
export REGION="your-region"
export ATTACHMENT_NAME="your-network-attachment-name"
export TEST_NAME="test-from-dms-attachment"
export DESTINATION_IP="your-source-database-ip"
export DESTINATION_PORT="your-source-database-port"

# 1. Extract the IP address assigned to the Network Attachment endpoint
SOURCE_IP=$(gcloud compute network-attachments describe "${ATTACHMENT_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --format="value(connectionEndpoints[0].ipAddress)")

echo "Extracted Source IP: ${SOURCE_IP}"

# 2. Extract the Network URI and strip the URL prefix
SOURCE_NETWORK_FULL_URI=$(gcloud compute network-attachments describe "${ATTACHMENT_NAME}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --format="value(network)")

SOURCE_NETWORK=${SOURCE_NETWORK_FULL_URI#https://www.googleapis.com/compute/v1/}

echo "Extracted Source Network: ${SOURCE_NETWORK}"

# 3. Create the connectivity test
gcloud network-management connectivity-tests create "${TEST_NAME}" \
    --project="${PROJECT_ID}" \
    --source-ip-address="${SOURCE_IP}" \
    --source-network="${SOURCE_NETWORK}" \
    --source-network-type="gcp-network" \
    --destination-ip-address="${DESTINATION_IP}" \
    --destination-port="${DESTINATION_PORT}" \
    --protocol=TCP

# 4. Rerun the test to get the latest reachability results and wait for completion
gcloud network-management connectivity-tests rerun "${TEST_NAME}" \
    --project="${PROJECT_ID}"
