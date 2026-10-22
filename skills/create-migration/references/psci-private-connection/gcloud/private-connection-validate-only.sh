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

# Example script showing how to query the DMS Tenant Project ID
# by performing a --validate-only private connection creation.

export DEST_PROJECT_ID="your-project-id"
export DEST_REGION="your-region"
export PRIVATE_CONN="your-private-connection-name"
export NETWORK_ATTACHMENT_URI="projects/your-project/regions/your-region/networkAttachments/your-attachment"

DMS_TENANT_ID=$(gcloud database-migration private-connections create "${PRIVATE_CONN}" \
  --project="${DEST_PROJECT_ID}" \
  --region="${DEST_REGION}" \
  --network-attachment="${NETWORK_ATTACHMENT_URI}" \
  --display-name="${PRIVATE_CONN}" \
  --format="value(metadata.metadata.tenant_project_id)" \
  --validate-only)

echo "${DMS_TENANT_ID}"
