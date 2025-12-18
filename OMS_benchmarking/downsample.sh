#!/bin/bash

set -e

# Help message
usage() {
    echo "Usage: $0 --target-gb <gb> --outdir <dir> --size-file <txt> [--prefix <name>] (--long-read <file> | --short-read1 <file> --short-read2 <file>)"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --long-read) long_read="$2"; shift ;;
        --short-read1) short_read1="$2"; shift ;;
        --short-read2) short_read2="$2"; shift ;;
        --target-gb) target_gb="$2"; shift ;;
        --outdir) outdir="$2"; shift ;;
        --prefix) prefix="$2"; shift ;;
        --size-file) size_file="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate required inputs
if [[ -z "$target_gb" || -z "$outdir" || -z "$size_file" ]]; then
    echo "Error: --target-gb, --outdir, and --size-file are required."
    usage
fi

prefix="${prefix:-downsampled}"
mkdir -p "$outdir"

# Read total bases from the provided size file
if [[ ! -f "$size_file" ]]; then
    echo "Error: Size file $size_file not found."
    exit 1
fi

total_bases=$(cat "$size_file")

if [[ -n "$long_read" ]]; then
    target_bases=$(awk -v gb="$target_gb" 'BEGIN {print gb * 1e9}')
else
    target_bases=$(awk -v gb="$target_gb" 'BEGIN {print gb * 1e9 * 2}')
fi

fraction=$(awk -v t="$target_bases" -v o="$total_bases" 'BEGIN {f = t / o; print (f < 1 ? f : 1)}')
echo "Subsampling fraction: $fraction"

# Downsampling logic
if [[ -n "$long_read" ]]; then
    echo "Detected long read file: $long_read"
    seqtk sample -s42 "$long_read" "$fraction" > "$outdir/${prefix}_long.fq"

elif [[ -n "$short_read1" && -n "$short_read2" ]]; then
    echo "Detected paired-end short reads:"
    echo "  R1: $short_read1"
    echo "  R2: $short_read2"
    seqtk sample -s42 "$short_read1" "$fraction" | gzip > "$outdir/${prefix}_1.fq.gz"
    seqtk sample -s42 "$short_read2" "$fraction" | gzip > "$outdir/${prefix}_2.fq.gz"
else
    echo "Error"
    usage
fi

echo "Downsampling complete. Output in $outdir/"