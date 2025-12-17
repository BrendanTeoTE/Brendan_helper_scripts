#!/usr/bin/env python3
import argparse, csv

ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="inp", required=True)
ap.add_argument("--out", dest="out", required=True)
args = ap.parse_args()

with open(args.inp) as f, open(args.out, "w") as out:
    r = csv.DictReader(f, delimiter="\t")
    w = csv.writer(out, delimiter="\t")
    w.writerow(["label","qtype","qval"])
    for row in r:
        w.writerow([row["label"], row["query_type"], row["query_value"]])
