#!/usr/bin/env python3
import argparse, sys, csv, re, os

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True)
    ap.add_argument("--out", dest="out", required=True)
    args = ap.parse_args()

    with open(args.inp, newline="") as f:
        reader = csv.reader(f, delimiter="\t")
        header = next(reader)
    # lowercased header name -> index
    cols = {h.strip().lower(): i for i, h in enumerate(header)}

    def pick(row, candidates):
        for c in candidates:
            i = cols.get(c)
            if i is not None:
                v = row[i].strip()
                if v:
                    return v
        return ""

    # helpers
    re_acc = re.compile(r"(GCF|GCA)_\d+\.\d+")
    def from_genome_file(row):
        gf = pick(row, ["genome_file"])
        if not gf:
            return ""
        m = re_acc.search(gf)
        return m.group(0) if m else ""

    def from_contig_name(row):
        cn = pick(row, ["contig_name"])
        # Try to extract a scientific name up to first comma (or whole token before comma)
        if not cn:
            return ""
        # If the line has a RefSeq accession like NZ_CP..., Datasets can't use that directly.
        # We'll fall back to name query.
        # Extract species part after accession, or just take text after first space.
        parts = cn.split(None, 1)
        if len(parts) == 2:
            name = parts[1].split(",")[0].strip()
        else:
            name = cn.strip()
        # sanitize for label
        label = re.sub(r"[^A-Za-z0-9_.-]+", "_", name)
        return label, name

    with open(args.inp, newline="") as f, open(args.out, "w", newline="") as out:
        reader = csv.reader(f, delimiter="\t")
        next(reader)  # skip header
        w = csv.writer(out, delimiter="\t", lineterminator="\n")
        w.writerow(["label", "query_type", "query_value", "abundance"])

        wrote_any = False
        for row in reader:
            if not row:
                continue

            # abundance: prefer Taxonomic_abundance, then Sequence_abundance, then older names
            ab_s = pick(row, [
                "taxonomic_abundance", "sequence_abundance",
                "abundance", "relative_abundance", "weight", "fraction"
            ]) or "0"
            try:
                ab = float(ab_s)
            except ValueError:
                ab = 0.0
            # If it looks like a percent, convert to fraction (run once)
            if ab > 1.0 and ab <= 100.0:
                ab = ab / 100.0
            if ab <= 0:
                continue

            # accession from Genome_file if possible
            acc = from_genome_file(row)

            # taxid if present
            tax = pick(row, ["taxid", "ncbi_taxid", "tax_id"])

            # name from common columns or from Contig_name
            name = pick(row, ["species", "name", "organism"])
            label_for_name = re.sub(r"[^A-Za-z0-9_.-]+", "_", name.strip()) if name else ""
            if not name:
                cn = from_contig_name(row)
                if cn:
                    label_for_name, name = cn

            if acc:
                w.writerow([acc, "accession", acc, f"{ab:.6f}"])
                wrote_any = True
            elif tax:
                w.writerow([tax, "taxon", tax, f"{ab:.6f}"])
                wrote_any = True
            elif name:
                w.writerow([label_for_name, "name", name, f"{ab:.6f}"])
                wrote_any = True
            # else: we cannot query this row, skip

    # optional: warn if nothing was written (besides header)
    # if not wrote_any:
    #     print("Warning: no rows written — check column names in input", file=sys.stderr)

if __name__ == "__main__":
    main()
