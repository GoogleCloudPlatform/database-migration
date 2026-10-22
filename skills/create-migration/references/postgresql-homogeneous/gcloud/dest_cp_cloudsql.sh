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

# Creates a DMS destination connection profile for a Cloud SQL instance.

export PROJECT_ID="your-project-id"
export REGION="your-region"
export DEST_CONN_ID="your-destination-conn-id"
export CLOUD_SQL_ID="your-cloudsql-instance-id"
export DESTINATION_HOST="your-destination-host-ip"
export DESTINATION_PORT="5432"
export DMS_USER="your-dms-user"
export DMS_PASS="your-dms-password"
export AGENT_NAME="your-agent-name"

gcloud database-migration connection-profiles create postgresql \
  "${DEST_CONN_ID}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --role=DESTINATION \
  --cloudsql-instance="${CLOUD_SQL_ID}" \
  --host="${DESTINATION_HOST}" \
  --port="${DESTINATION_PORT}" \
  --username="${DMS_USER}" \
  --password="${DMS_PASS}" \
  --labels="agent=${AGENT_NAME}"
