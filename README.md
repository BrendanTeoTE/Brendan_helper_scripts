# OPERA-MS benchmarking

Works for the following branch/version of OPERA-MS: https://github.com/BrendanTeoTE/OPERA-MS/tree/skani

This pipeline is able to downsample long read and short reads into a specified size in number of bases (gb), and run OPERA-MS for all possible combinations with the ability to select between Mash and Skani for reference clustering, or use both methods. Snakemake benchmarks will be produced for each step of OPERA-MS. 

Edit the config file, config.large.json, with the name of the sample, e.g "schoenbuch_test" in the example. Also input the path to the root directory of OPERA-MS. Select short and long reads, and downsampling target sizes (If no downsampling is required, use "short_read_gb": ["full"], and similarly for long reads). Indicate output directory for results, and the method for reference clustering to be used.

Also requires Snakemake installed in the environment. Run this following command from the root directory.

"
snakemake -c 32 -p --configfile config.large.json --rerun-triggers mtime --keep-going --dry-run
"

To plot heatmaps from benchmark files in the benchmark folder, use:

"
python heatmap.py \
  --sample-prefix {name of sample} \
  --dir benchmarks \
  --outdir {path} \
  --metric {wall_time/cpu_time/mean_load/mean_cpu_load/max_rss} \
  --tool {mash/skani}
"

# Simulating Reads

test_dataset is a pipeline used to generate simulated reads from an initial sylph profile using ISS and badreads. Copy the repository, and add the sylph profile you want to simulate to the root directory. You will need an NCBI key, snakemake, ISS and badreads installed in your conda environment. Edit the configuration file, config/samples.json accordingly, with the sylph profile, and target size of simulated short and long reads.

Run it like this.
```
export NCBI_API_KEY=your_ncbi_key
snakemake -c 32 -p --configfile config/samples.json --rerun-triggers mtime --use-conda --rerun-incomplete
```

# Downsampling

Downsamples short reads by reading up to a specified amount of bases (in GB), writing it in a new downsampled file, and discarding the rest. Saves time as it does not need to read the entirety of the fastq file.

Run it like this.
```
                    ./awk_faster_downsample.sh \
                      -1 {input.r1} \
                      -2 {input.r2} \
                      -g {Target number of bases (in GB)} \
                      -o {Outdir} \
                      -t 1 \
```
                      
                    
