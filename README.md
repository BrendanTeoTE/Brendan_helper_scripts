# Simulating Reads

test_dataset is a pipeline used to generate simulated reads from an initial sylph profile using ISS and badreads. Copy the repository, and add the sylph profile you want to simulate to the root directory. You will need an NCBI key and snakemake installed in your conda environment. Edit the configuration file, config/samples.json accordingly, with the sylph profile, and target size of simulated short and long reads

Run
``` export NCBI_API_KEY=your_ncbi_key
snakemake -c 32 -p --configfile config/samples.json --rerun-triggers mtime --use-conda--dry-run --rerun-incomplete ```
