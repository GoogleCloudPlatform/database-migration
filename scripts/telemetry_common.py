#!/usr/bin/env python3
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Shared helpers for the plugin's telemetry hooks."""

import json
import os
import sys
import urllib.request

# Per-user directory shared by all installations of the plugin.
USER_DATA_DIR = os.path.join(
    os.path.expanduser("~"), ".google-database-migration"
)
STATE_FILE = os.path.join(USER_DATA_DIR, "state.json")
CONFIG_FILE = os.path.join(USER_DATA_DIR, "config.json")

WRITE_ARTIFACT_EVENTS = {
    "global_roles.sql": "users_permissions_scripts_generated",
    "users_permissions_assessment_report.md": (
        "users_permissions_assessment_completed"
    ),
    "users_permissions_migration_report.md": (
        "users_permissions_migration_completed"
    ),
}


def get_write_artifact_event_name(file_path):
  """Returns the telemetry event name for a tracked write artifact, or None."""
  if not isinstance(file_path, str):
    return None
  return WRITE_ARTIFACT_EVENTS.get(os.path.basename(file_path))


def is_telemetry_enabled():
  """Returns False if the user opted out of telemetry.

  Users opt out by setting DO_NOT_TRACK to 1 or true, or by setting
  "enableTelemetry": false in CONFIG_FILE.
  """
  do_not_track = os.environ.get("DO_NOT_TRACK", "").strip().lower()
  if do_not_track in ("1", "true"):
    return False

  try:
    with open(CONFIG_FILE, "r") as f:
      config = json.load(f)
  except (OSError, ValueError):
    return True
  if not isinstance(config, dict):
    return True
  enable_telemetry = config.get("enableTelemetry", True)
  return not isinstance(enable_telemetry, bool) or enable_telemetry


def get_global_session_metadata():
  """Returns event parameters read from the current migration session."""
  metadata = {
      "iac_mode": "unknown",
      "source_engine": "unknown",
      "destination_engine": "unknown",
      "agent_name": "unknown",
      "agent_session_id": "unknown",
  }

  try:
    if os.path.exists(STATE_FILE):
      with open(STATE_FILE, "r") as f:
        state = json.load(f)
        global_session = state.get("global_session", {})

        metadata["iac_mode"] = global_session.get("iac_mode", "unknown")
        metadata["source_engine"] = global_session.get(
            "source_engine", "unknown"
        )
        metadata["destination_engine"] = global_session.get(
            "destination_engine", "unknown"
        )
        metadata["agent_name"] = global_session.get("agent_name", "unknown")
        metadata["agent_session_id"] = global_session.get(
            "session_id", "unknown"
        )

  except (OSError, ValueError, AttributeError) as e:
    print(
        f"Error in get_global_session_metadata. Error: {str(e)}",
        file=sys.stderr,
    )

  return metadata


def send_ga_event(event_name, params, conversation_id):
  """Sends a single event to Google Analytics, ignoring network errors."""
  measurement_id = "G-51J9GBWXK3"
  api_secret = "BuSIuqhVQ1umKr-KIAZykw"
  client_id = (
      conversation_id if conversation_id else "dms-plugin-anonymous-user"
  )

  payload = {
      "client_id": client_id,
      "events": [{
          "name": event_name,
          "params": params,
      }],
  }

  url = (
      "https://www.google-analytics.com/mp/collect"
      f"?measurement_id={measurement_id}&api_secret={api_secret}"
  )

  req = urllib.request.Request(
      url,
      data=json.dumps(payload).encode("utf-8"),
      headers={"Content-Type": "application/json"},
      method="POST",
  )

  try:
    urllib.request.urlopen(req, timeout=5)
  except OSError:
    pass
