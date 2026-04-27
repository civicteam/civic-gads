#!/bin/bash

# Copyright 2025 Google LLC
# Copyright 2026 Civic Technologies, Inc.
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

# Description:
#   Initializes the development environment for civic-gads (the Google Ads API
#   Developer Assistant for Claude Code).
#   1. Verifies that git is installed.
#   2. Clones or updates the selected Google Ads client library repos
#      under client_libs/ so the agent can Grep/Read them locally.
#   3. Prints next steps for using the plugin in Claude Code.

set -eu

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

# --- Project Directory Resolution ---
if ! PROJECT_DIR_ABS=$(git rev-parse --show-toplevel 2>/dev/null); then
  err "ERROR: This script must be run from within the civic-gads git repository."
  exit 1
fi
readonly PROJECT_DIR_ABS
echo "Detected project root: ${PROJECT_DIR_ABS}"

# --- Configuration ---
readonly DEFAULT_PARENT_DIR="${PROJECT_DIR_ABS}/client_libs"
readonly ALL_LANGS="python php ruby java dotnet"

get_repo_url() {
  case "$1" in
    python) echo "https://github.com/googleads/google-ads-python.git" ;;
    php)    echo "https://github.com/googleads/google-ads-php.git" ;;
    ruby)   echo "https://github.com/googleads/google-ads-ruby.git" ;;
    java)   echo "https://github.com/googleads/google-ads-java.git" ;;
    dotnet) echo "https://github.com/googleads/google-ads-dotnet.git" ;;
  esac
}

get_repo_name() {
  case "$1" in
    python) echo "google-ads-python" ;;
    php)    echo "google-ads-php" ;;
    ruby)   echo "google-ads-ruby" ;;
    java)   echo "google-ads-java" ;;
    dotnet) echo "google-ads-dotnet" ;;
  esac
}

# --- Defaults (Bash 3.2 compatible) ---
INSTALL_PYTHON=true
INSTALL_PHP=false
INSTALL_RUBY=false
INSTALL_JAVA=false
INSTALL_DOTNET=false
ANY_SELECTED=false

# --- Dependency Check ---
if ! command -v git &> /dev/null; then
  err "ERROR: git is not installed. Please install it to continue."
  exit 1
fi

# --- Help ---
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "  Clones/updates Google Ads client libraries into client_libs/."
  echo "  The google-ads-python library is always installed by default."
  echo ""
  echo "  Options:"
  echo "    -h, --help                 Show this help message and exit"
  echo "    --php                      Include google-ads-php"
  echo "    --ruby                     Include google-ads-ruby"
  echo "    --java                     Include google-ads-java"
  echo "    --dotnet                   Include google-ads-dotnet"
  echo ""
  echo "  Example:"
  echo "    $0 --java                  (Installs Java and Python libraries)"
  echo ""
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --php)    INSTALL_PHP=true;    ANY_SELECTED=true; shift ;;
    --ruby)   INSTALL_RUBY=true;   ANY_SELECTED=true; shift ;;
    --java)   INSTALL_JAVA=true;   ANY_SELECTED=true; shift ;;
    --dotnet) INSTALL_DOTNET=true; ANY_SELECTED=true; shift ;;
    *)
      err "ERROR: Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "${ANY_SELECTED}" == "false" ]]; then
  echo "No additional languages selected. Defaulting to Python only."
fi

echo "Ensuring default library directory exists: ${DEFAULT_PARENT_DIR}"
mkdir -p "${DEFAULT_PARENT_DIR}" || { err "ERROR: Failed to create ${DEFAULT_PARENT_DIR}"; exit 1; }

is_enabled() {
  case "$1" in
    python) [[ "${INSTALL_PYTHON}" == "true" ]] ;;
    php)    [[ "${INSTALL_PHP}" == "true" ]] ;;
    ruby)   [[ "${INSTALL_RUBY}" == "true" ]] ;;
    java)   [[ "${INSTALL_JAVA}" == "true" ]] ;;
    dotnet) [[ "${INSTALL_DOTNET}" == "true" ]] ;;
    *)      return 1 ;;
  esac
}

# --- Clone/Update ---
clone_or_update() {
  local repo_url="$1"
  local clone_path="$2"
  local repo_name
  repo_name=$(basename "${clone_path}")

  echo "Managing repository ${repo_name} in ${clone_path}"
  if [[ -d "${clone_path}/.git" ]]; then
    echo "Directory ${clone_path} already exists. Updating..."
    if ! (cd "${clone_path}" && git pull); then
      echo "WARN: Failed to update ${repo_name}. Continuing..."
    else
      echo "Successfully updated ${repo_name}."
    fi
  elif [[ -d "${clone_path}" ]]; then
    echo "WARN: Directory ${clone_path} exists but is not a git repo. Skipping."
  else
    echo "Cloning ${repo_url} into ${clone_path}"
    if ! git clone "${repo_url}" "${clone_path}"; then
      err "ERROR: Failed to clone ${repo_url}"
      exit 1
    fi
    echo "Successfully cloned ${repo_name}."
  fi
}

for lang in $ALL_LANGS; do
  if is_enabled "$lang"; then
    repo_name=$(get_repo_name "$lang")
    url=$(get_repo_url "$lang")
    clone_or_update "$url" "${DEFAULT_PARENT_DIR}/${repo_name}"
  fi
done

cat <<EOF

✓ civic-gads installation complete.

Cloned client libraries are under: ${DEFAULT_PARENT_DIR}/
The agent will Grep/Read them locally — no settings changes required.

Next steps:
  1. Ensure ~/google-ads.yaml exists with valid credentials (or one of the
     fallback configs: ~/google_ads_php.ini, ~/google_ads_config.rb,
     ~/ads.properties). See SERVICE_ACCOUNT.md for service-account setup.
  2. Open this directory in Claude Code:
       cd ${PROJECT_DIR_ABS} && claude
  3. The SessionStart hook will create .venv/, install google-ads + ruff,
     and copy your credentials into ./config/.
  4. Try a prompt like: "Show me campaigns with the most conversions in
     the last 30 days for customer 1234567890."

IMPORTANT: You must configure and verify the development environment for
each language you wish to use.
EOF
