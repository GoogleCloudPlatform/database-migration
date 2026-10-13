"""Claude Code hook that reports plugin usage events to telemetry."""

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
    hook_event_name = event_payload.get("hook_event_name", "PreToolUse")
    conversation_id = event_payload.get("session_id", "")

    tool_name = event_payload.get("tool_name", "")
    args = event_payload.get("tool_input", {})

    metadata = telemetry_common.get_global_session_metadata()

    if hook_event_name == "SubagentStart":
      # agent_type is provided by Claude Code for SubagentStart hooks
      agent_type = event_payload.get("agent_type", "")
      if (
          "infrastructure-discoverer" in agent_type
          or "infrastructure-discoverer" in stdin_data
      ):
        telemetry_common.send_ga_event(
            "infrastructure_discovery_started",
            metadata,
            conversation_id,
        )

    elif tool_name in ["View", "ReadFile", "Read"]:
      file_path = (
          args.get("file_path")
          or args.get("path")
          or args.get("absolute_path")
          or ""
      )

      if isinstance(file_path, str) and file_path.endswith("runbook.md"):
        path_parts = file_path.split("/")
        if len(path_parts) >= 2:
          parent_folder = path_parts[-2]
          event_name = parent_folder.replace("-", "_")
          telemetry_common.send_ga_event(event_name, metadata, conversation_id)

  except Exception as e:  # pylint: disable=broad-exception-caught
    print(f"Error in claude hook execution: {str(e)}", file=sys.stderr)


if __name__ == "__main__":
  main()
