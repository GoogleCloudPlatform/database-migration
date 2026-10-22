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

"""Antigravity (agy) hook that reports plugin usage events to telemetry."""

import json
import sys

import telemetry_common


def main():
  """Reads the hook event from stdin and sends a matching telemetry event."""
  try:
    stdin_data = sys.stdin.read()

    if not stdin_data or not telemetry_common.is_telemetry_enabled():
      return

    event_payload = json.loads(stdin_data)

    conversation_id = event_payload.get("conversationId", "")

    tool_call = event_payload.get("toolCall", {})
    tool_name = tool_call.get("name", "")
    args = tool_call.get("args", {})

    metadata = telemetry_common.get_global_session_metadata()

    if tool_name == "invoke_subagent":
      is_infra = False
      for sa in args.get("Subagents", []):
        if sa.get("TypeName") == "infrastructure-discoverer":
          is_infra = True

      if is_infra:
        telemetry_common.send_ga_event(
            "infrastructure_discovery_started",
            metadata,
            conversation_id,
        )

    elif tool_name in ["view_file", "read_file"]:
      file_path = (
          args.get("AbsolutePath")
          or args.get("Path")
          or args.get("file_path")
          or args.get("path")
          or ""
      )

      if isinstance(file_path, str) and file_path.endswith("runbook.md"):
        path_parts = file_path.split("/")
        if len(path_parts) >= 2:
          parent_folder = path_parts[-2]
          event_name = parent_folder.replace("-", "_")
          telemetry_common.send_ga_event(event_name, metadata, conversation_id)

    elif tool_name in ["write_to_file", "write_file"]:
      file_path = (
          args.get("TargetFile")
          or args.get("Path")
          or args.get("AbsolutePath")
          or args.get("file_path")
          or args.get("path")
          or ""
      )
      event_name = telemetry_common.get_write_artifact_event_name(file_path)
      if event_name:
        telemetry_common.send_ga_event(event_name, metadata, conversation_id)

  except Exception as e:  # pylint: disable=broad-exception-caught
    print(f"Error in agy hook execution: {str(e)}", file=sys.stderr)


if __name__ == "__main__":
  main()
