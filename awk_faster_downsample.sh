#!/usr/bin/env bash
# truncate paired FASTQ/FASTQ.GZ to ~G gigabases total (R1+R2)
set -euo pipefail

R1=""; R2=""; G=""; OUTPREFIX=""; T=0   

die(){ echo "[ERROR] $*" >&2; exit 1; }
usage(){ cat <<USAGE
Usage: $(basename "$0") -1 R1.fq[.gz] -2 R2.fq[.gz] -g GBASES -o OUTPREFIX [-t THREADS]
  -1 / -2   Input FASTQ (optionally gzipped)
  -g        Target gigabases (R1+R2 combined)
  -o        Output prefix (<prefix>_1.fq[.gz], <prefix>_2.fq[.gz])
  -t        Threads for pigz (0=all cores; default 0). Ignored if pigz not found.
USAGE
}

while getopts ":1:2:g:o:t:h" opt; do
  case "$opt" in
    1) R1="$OPTARG" ;;
    2) R2="$OPTARG" ;;
    g) G="$OPTARG" ;;
    o) OUTPREFIX="$OPTARG" ;;
    t) T="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) die "Option -$OPTARG requires an argument" ;;
    \?) die "Unknown option: -$OPTARG (use -h)" ;;
  esac
done

[[ -n "$R1" && -n "$R2" && -n "$OUTPREFIX" ]] || { usage; die "Missing -1/-2/-o"; }
[[ -e "$R1" ]] || die "R1 not found: $R1"
[[ -e "$R2" ]] || die "R2 not found: $R2"
[[ "${G:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "-g must be a number (gigabases), got '$G'"


if command -v mawk >/dev/null 2>&1; then AWK=mawk; else AWK=awk; fi

OUT1="${OUTPREFIX}_1.fq$([[ "$R1" == *.gz ]] && echo .gz)"
OUT2="${OUTPREFIX}_2.fq$([[ "$R2" == *.gz ]] && echo .gz)"
outdir="$(dirname "$OUT1")"
[[ "$outdir" != "." ]] && mkdir -p "$outdir"

HAVE_PIGZ=0
PIGZ_P=()
if command -v pigz >/dev/null 2>&1; then
  HAVE_PIGZ=1
  [[ "${T:-0}" != "0" ]] && PIGZ_P=(-p "$T")
fi

#read
if [[ "$R1" == *.gz ]]; then
  if (( HAVE_PIGZ )); then R1CMD=(pigz -dc "${PIGZ_P[@]}" -- "$R1"); else R1CMD=(gzip -cd -- "$R1"); fi
else
  R1CMD=(cat -- "$R1")
fi

if [[ "$R2" == *.gz ]]; then
  if (( HAVE_PIGZ )); then R2CMD=(pigz -dc "${PIGZ_P[@]}" -- "$R2"); else R2CMD=(gzip -cd -- "$R2"); fi
else
  R2CMD=(cat -- "$R2")
fi

#write
if [[ "$OUT1" == *.gz ]]; then
  if (( HAVE_PIGZ )); then OUT1CMD="pigz -c ${PIGZ_P[*]} > '$(printf %q "$OUT1")'"; else OUT1CMD="gzip -c > '$(printf %q "$OUT1")'"; fi
else
  OUT1CMD="cat > '$(printf %q "$OUT1")'"
fi

if [[ "$OUT2" == *.gz ]]; then
  if (( HAVE_PIGZ )); then OUT2CMD="pigz -c ${PIGZ_P[*]} > '$(printf %q "$OUT2")'"; else OUT2CMD="gzip -c > '$(printf %q "$OUT2")'"; fi
else
  OUT2CMD="cat > '$(printf %q "$OUT2")'"
fi

TARGET_BASES=$($AWK -v g="$G" 'BEGIN{printf("%d", g*1e9 + 0.5)}')
#TARGET_BASES=$(( G * 1000000000 ))

export LC_ALL=C

start_ts=$(date +%s)
total_file="$(mktemp)"; trap 'rm -f "$total_file"' EXIT

# awk
r1q="$(printf '%q ' "${R1CMD[@]}")"
r2q="$(printf '%q ' "${R2CMD[@]}")"

$AWK -v r1cmd="$r1q" \
     -v r2cmd="$r2q" \
     -v out1="$OUT1CMD" -v out2="$OUT2CMD" \
     -v target="$TARGET_BASES" \
     -v total_out="$total_file" '
BEGIN{
  writer1 = "bash -lc \"" out1 "\""
  writer2 = "bash -lc \"" out2 "\""
  r1 = "bash -lc \"" r1cmd "\""
  r2 = "bash -lc \"" r2cmd "\""

  total1 = 0; total2 = 0
  while (1) {
    if ((r1 | getline h1) <= 0) break
    if ((r1 | getline s1) <= 0) break
    if ((r1 | getline p1) <= 0) break
    if ((r1 | getline q1) <= 0) break

    if ((r2 | getline h2) <= 0) break
    if ((r2 | getline s2) <= 0) break
    if ((r2 | getline p2) <= 0) break
    if ((r2 | getline q2) <= 0) break

    total1 += length(s1)
    total2 += length(s2)

    print h1 | writer1; print s1 | writer1; print p1 | writer1; print q1 | writer1
    print h2 | writer2; print s2 | writer2; print p2 | writer2; print q2 | writer2

    if (total1 >= target && total2 >= target) break
  }

  close(r1); close(r2)
  close(writer1); close(writer2)

  print (total1 + total2) > total_out
  printf("[INFO] R1=%.3f Gb, R2=%.3f Gb (target per end %.3f)\n",
         total1/1e9, total2/1e9, target/1e9) > "/dev/stderr"
}
' < /dev/null


end_ts=$(date +%s)
elapsed=$(( end_ts - start_ts ))

total_bases=$(cat "$total_file")
gbases=$($AWK -v t="$total_bases" 'BEGIN{printf("%.3f", t/1e9)}')
rate=$($AWK -v t="$total_bases" -v s="$elapsed" 'BEGIN{ if(s>0) printf("%.3f", (t/1e9)/s); else print "inf"}')

echo "[TIME] Elapsed: ${elapsed}s"
echo "[TIME] Throughput: ${rate} Gbases/s"
echo "[OK] Outputs:"
echo "  $OUT1"
echo "  $OUT2"
