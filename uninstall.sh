#!/bin/bash

# Copyright 2025 Google LLC
# Copyright 2026 Civic Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0

# Description:
#   Removes the local civic-gads project directory.
#   (Claude Code plugins do not require an external "uninstall" registration step.)

set -eu

if ! PROJECT_DIR_ABS=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "ERROR: This script must be run from within the civic-gads git repository."
  exit 1
fi

echo "This will DELETE the entire directory: ${PROJECT_DIR_ABS}"
read -p "Are you sure you want to proceed? (Y/n): " confirm

if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
  echo "Uninstallation cancelled."
  exit 0
fi

echo "Removing project directory: ${PROJECT_DIR_ABS}..."
parent_dir=$(dirname "${PROJECT_DIR_ABS}")
project_name=$(basename "${PROJECT_DIR_ABS}")

cd "${parent_dir}"
rm -rf "${project_name}"

echo "Uninstallation complete."
