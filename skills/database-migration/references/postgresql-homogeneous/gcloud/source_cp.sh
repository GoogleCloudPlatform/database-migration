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

# Creates a DMS source connection profile for a PostgreSQL database.

export PROJECT_ID="your-project-id"
export REGION="your-region"
export SOURCE_CONN_ID="your-source-conn-id"
export SOURCE_INSTANCE_IP="your-source-ip"
export SOURCE_PORT="5432"
export SOURCE_USER="your-source-user"
export SOURCE_PASSWORD="your-source-password"
export PRIVATE_CONN="your-private-connection-id"
export AGENT_NAME="your-agent-name"

gcloud database-migration connection-profiles create postgresql \
  "${SOURCE_CONN_ID}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --role=SOURCE \
  --host="${SOURCE_INSTANCE_IP}" \
  --port="${SOURCE_PORT}" \
  --username="${SOURCE_USER}" \
  --password="${SOURCE_PASSWORD}" \
  --ssl-type=REQUIRED \
  --private-connection="${PRIVATE_CONN}" \
  --labels="agent=${AGENT_NAME}"
