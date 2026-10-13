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

# Creates and starts a DMS continuous migration job (migrating all databases) using PostgreSQL native logical replication.

export PROJECT_ID="your-project-id"
export REGION="your-region"
export MJ_ID="your-migration-job-id"
export SOURCE_CONN_ID="your-source-conn-id"
export DEST_CONN_ID="your-dest-conn-id"
export AGENT_NAME="your-agent-name"
export OP_ID="your-operation-id"

# 1. Create the continuous migration job using postgres native logical replication
gcloud database-migration migration-jobs create "${MJ_ID}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --type=CONTINUOUS \
  --source="${SOURCE_CONN_ID}" \
  --destination="${DEST_CONN_ID}" \
  --use-postgres-native \
  --all-databases \
  --no-async \
  --labels="agent=${AGENT_NAME}"

# 2. Verify the migration job to check for warnings or blocks
gcloud database-migration migration-jobs verify "${MJ_ID}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}"

# Describe the verification operation to retrieve output (OP_ID must be parsed from previous step's output)
gcloud database-migration operations describe "${OP_ID}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}"

# 3. Start the migration job after verification succeeds
gcloud database-migration migration-jobs start "${MJ_ID}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}"
