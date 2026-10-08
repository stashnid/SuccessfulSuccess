#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "${script_dir}/.." && pwd)
output_file=${1:-/tmp/successfulsuccess-report-mailer.zip}

rm -f -- "${output_file}"
(cd "${project_dir}/backend/app/reports" && zip -q -j "${output_file}" mailer_handler.py)
printf '%s\n' "${output_file}"
