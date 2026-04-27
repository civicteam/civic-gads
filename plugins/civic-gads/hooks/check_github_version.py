#!/usr/bin/env python3
# Copyright 2026 Google LLC
# Copyright 2026 Civic Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0

import json
import logging
import os
import re
import sys
import urllib.request

# Script is at <plugin_root>/hooks/<file>. plugin_root is one level up.
plugin_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log_path = os.path.join(plugin_root, "check_github_version.log")

logger = logging.getLogger()
logger.setLevel(logging.INFO)

file_handler = logging.FileHandler(log_path)
file_handler.setLevel(logging.INFO)
file_handler.setFormatter(
    logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
)
logger.addHandler(file_handler)

stream_handler = logging.StreamHandler(sys.stderr)
stream_handler.setLevel(logging.WARNING)
stream_handler.setFormatter(
    logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
)
logger.addHandler(stream_handler)


# Override-able via env var so this works for both the public Gemini upstream
# and a future Civic-hosted fork. Set CIVIC_GADS_REMOTE_PLUGIN_JSON_URL to
# enable a real remote check; if unset, the check is skipped silently.
DEFAULT_REMOTE_URL = os.environ.get("CIVIC_GADS_REMOTE_PLUGIN_JSON_URL", "")


def get_local_version():
    """Read the local plugin version from .claude-plugin/plugin.json."""
    json_path = os.path.join(plugin_root, ".claude-plugin", "plugin.json")

    try:
        with open(json_path, "r") as f:
            data = json.load(f)
            return data.get("version")
    except Exception as e:
        logging.error(f"Error reading local version: {e}")
        return None


def get_remote_version():
    if not DEFAULT_REMOTE_URL:
        logging.info(
            "CIVIC_GADS_REMOTE_PLUGIN_JSON_URL not set; skipping remote version check."
        )
        return None

    try:
        with urllib.request.urlopen(DEFAULT_REMOTE_URL, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                return data.get("version")
            logging.error(
                f"Failed to fetch remote version, status: {response.status}"
            )
            return None
    except Exception as e:
        logging.error(f"Error fetching remote version: {e}")
        return None


def parse_version(v_str):
    """Parse semver-ish version strings, ignoring any prerelease/build suffix."""
    nums = re.findall(r"\d+", v_str.split("-", 1)[0])
    return tuple(int(n) for n in nums) if nums else (0,)


def main():
    logging.info("Checking for extension updates...")
    local_version = get_local_version()
    remote_version = get_remote_version()

    if not local_version or not remote_version:
        logging.info("Could not complete version check.")
        return

    logging.info(
        f"Local version: {local_version}, Remote version: {remote_version}"
    )

    try:
        if parse_version(remote_version) > parse_version(local_version):
            logging.warning(
                f"A new version of civic-gads is available: {remote_version}"
            )
            logging.warning("Please run `./update.sh` to update.")
        else:
            logging.info("civic-gads is up to date.")
    except Exception as e:
        logging.error(f"Error comparing versions: {e}")


if __name__ == "__main__":
    main()
