#!/usr/bin/env bash
# download_by_resolved.sh
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 resolved_genomes.tsv OUTDIR" >&2
  exit 1
fi

tsv="$1"
outdir="$2"
mkdir -p "$outdir"

# use API key if present
API_FLAG=""
if [ -n "${NCBI_API_KEY:-}" ]; then
  API_FLAG="--api-key $NCBI_API_KEY"
fi

# skip header; read columns: label qtype qval
tail -n +2 "$tsv" | while IFS=$'\t' read -r label qtype qval || [ -n "${label:-}" ]; do
  [ -z "${label:-}" ] && continue
  [ "$qtype" != "accession" ] && { echo "Skipping $label (qtype=$qtype)"; continue; }

  zip="$outdir/${label}.zip"
  echo "[*] $label -> $zip"
  datasets download genome accession "$qval" --include genome $API_FLAG --filename "$zip"
done
