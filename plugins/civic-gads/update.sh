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
#   Updates civic-gads and any cloned client libraries.
#   1. Backs up customer_id.txt and .claude/settings.json (if locally modified).
#   2. git pull on the project repo.
#   3. Restores user customizations.
#   4. Optionally clones additional client libraries (--php, --ruby, --java, --dotnet).
#   5. git pull on every existing client_libs/<repo>/.

set -eu

err() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2; }

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "  Updates civic-gads and configured client libraries."
  echo ""
  echo "  Options:"
  echo "    -h, --help    Show this help message and exit"
  echo "    --python      Ensure google-ads-python is present and updated"
  echo "    --php         Ensure google-ads-php is present and updated"
  echo "    --ruby        Ensure google-ads-ruby is present and updated"
  echo "    --java        Ensure google-ads-java is present and updated"
  echo "    --dotnet      Ensure google-ads-dotnet is present and updated"
  echo ""
}

INSTALL_PYTHON=false
INSTALL_PHP=false
INSTALL_RUBY=false
INSTALL_JAVA=false
INSTALL_DOTNET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --python) INSTALL_PYTHON=true; shift ;;
    --php)    INSTALL_PHP=true;    shift ;;
    --ruby)   INSTALL_RUBY=true;   shift ;;
    --java)   INSTALL_JAVA=true;   shift ;;
    --dotnet) INSTALL_DOTNET=true; shift ;;
    *) shift ;;
  esac
done

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

is_enabled() {
  case "$1" in
    python) [[ "${INSTALL_PYTHON}" == "true" ]] ;;
    php)    [[ "${INSTALL_PHP}"    == "true" ]] ;;
    ruby)   [[ "${INSTALL_RUBY}"   == "true" ]] ;;
    java)   [[ "${INSTALL_JAVA}"   == "true" ]] ;;
    dotnet) [[ "${INSTALL_DOTNET}" == "true" ]] ;;
  esac
}

if ! command -v git &> /dev/null; then
  err "ERROR: git is not installed."
  exit 1
fi

if ! PROJECT_DIR_ABS=$(git rev-parse --show-toplevel 2>/dev/null); then
  err "ERROR: Run this from inside the civic-gads git repository."
  exit 1
fi
readonly PROJECT_DIR_ABS
echo "Detected project root: ${PROJECT_DIR_ABS}"

# --- Backup user-customized files before pull ---
SETTINGS_JSON=".claude/settings.json"
CUSTOMER_ID_FILE="customer_id.txt"
TEMP_SETTINGS=$(mktemp)
TEMP_CUSTOMER_ID=$(mktemp)
trap 'rm -f "${TEMP_SETTINGS}" "${TEMP_CUSTOMER_ID}"' EXIT

backup_and_reset() {
  local file="$1"
  local tmp="$2"
  if [[ -f "${file}" ]]; then
    cp "${file}" "${tmp}"
    if git ls-files --error-unmatch "${file}" &> /dev/null; then
      echo "Resetting ${file} to avoid merge conflicts..."
      git checkout "${file}"
    fi
  fi
}

backup_and_reset "${SETTINGS_JSON}"  "${TEMP_SETTINGS}"
backup_and_reset "${CUSTOMER_ID_FILE}" "${TEMP_CUSTOMER_ID}"

echo "Updating civic-gads..."
if ! git pull; then
  err "ERROR: git pull failed."
  [[ -s "${TEMP_SETTINGS}" ]]    && mv "${TEMP_SETTINGS}"    "${SETTINGS_JSON}"
  [[ -s "${TEMP_CUSTOMER_ID}" ]] && mv "${TEMP_CUSTOMER_ID}" "${CUSTOMER_ID_FILE}"
  exit 1
fi

# --- Restore user files ---
if [[ -s "${TEMP_SETTINGS}" ]]; then
  echo "Restoring local ${SETTINGS_JSON} (overwrites repo defaults)."
  mv "${TEMP_SETTINGS}" "${SETTINGS_JSON}"
fi
if [[ -s "${TEMP_CUSTOMER_ID}" ]]; then
  echo "Restoring local ${CUSTOMER_ID_FILE}."
  mv "${TEMP_CUSTOMER_ID}" "${CUSTOMER_ID_FILE}"
fi

# --- Ensure requested client libs exist ---
readonly DEFAULT_PARENT_DIR="${PROJECT_DIR_ABS}/client_libs"
readonly ALL_LANGS="python php ruby java dotnet"
mkdir -p "${DEFAULT_PARENT_DIR}"

for lang in $ALL_LANGS; do
  if is_enabled "$lang"; then
    repo_url=$(get_repo_url "$lang")
    repo_name=$(get_repo_name "$lang")
    lib_path="${DEFAULT_PARENT_DIR}/${repo_name}"
    if [[ ! -d "${lib_path}" ]]; then
      echo "Cloning ${repo_name}..."
      git clone "${repo_url}" "${lib_path}" || { err "ERROR: clone failed for ${repo_url}"; exit 1; }
    fi
  fi
done

# --- Pull every existing client lib ---
echo "Updating client libraries under ${DEFAULT_PARENT_DIR}..."
shopt -s nullglob
for lib_path in "${DEFAULT_PARENT_DIR}"/*/; do
  if [[ -d "${lib_path}/.git" ]]; then
    echo "Updating ${lib_path}..."
    (cd "${lib_path}" && git pull) || err "WARN: pull failed for ${lib_path}; continuing"
  fi
done

echo "Update complete."
