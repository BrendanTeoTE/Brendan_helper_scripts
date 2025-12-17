#!/usr/bin/env python3
import argparse, csv

ap = argparse.ArgumentParser()
ap.add_argument("--profile", required=True)
ap.add_argument("--sizes", required=True)
ap.add_argument("--out", required=True)
# keep old --depth for backwards compatibility
ap.add_argument("--depth", type=float, default=None)
# new: total budget in bases
ap.add_argument("--budget-bases", type=int, default=None)
args = ap.parse_args()

# read profile: label, abundance
abund = {}  # label -> fraction
with open(args.profile) as f:
    r = csv.DictReader(f, delimiter="\t")
    for row in r:
        a = float(row.get("abundance", 0) or 0)
        if a > 0:
            abund[row["label"]] = a
tot = sum(abund.values()) or 1.0
for k in list(abund):
    abund[k] /= tot  # normalize to sum=1

# read sizes: label, size_bp
sizes = {}
with open(args.sizes) as f:
    for lab, sz in csv.reader(f, delimiter="\t"):
        try:
            sizes[lab] = int(sz)
        except:
            pass

with open(args.out, "w") as out:
    print("label\tcoverage", file=out)
    if args.budget_bases is not None:
        B = int(args.budget_bases)
        for lab, a in abund.items():
            L = sizes.get(lab, 0)
            cov = (B * a / L) if L > 0 else 0.0
            print(f"{lab}\t{cov:.6f}", file=out)
    else:
        community_bp = sum(sizes.get(l,0) * abund.get(l,0) for l in abund)
        D = float(args.depth or 0.0)
        for lab, a in abund.items():
            L = sizes.get(lab, 0)
            cov = (D * a * (community_bp / L)) if L > 0 else 0.0
            print(f"{lab}\t{cov:.6f}", file=out)

