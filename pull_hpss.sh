#! /bin/bash
#SBATCH --job-name=pull_hpss
#SBATCH --output=pull_hpss.out
#SBATCH --error=pull_hpss.err
#SBATCH --time=06:00:00
#SBATCH --partition=u1-service
#SBATCH --ntasks=16
#SBATCH --account=hfv3gfs
#SBATCH --qos=batch
#SBATCH --open-mode=truncate

echo "Starting pull_hpss.sh script"
n_tasks=$SLURM_NTASKS

start_date=20260801
end_date=20260930

root_dir="/5year/NCEPDEV/emc-global/emc.glopara/WCOSS2/GFSv17/retrov17_01_realtime"
tarball_name="gfsa.tar"

hostname
set -ex

# Loop through all possible dates and untar the tarball for each date
cur_date=$start_date
concurrent_jobs=0
# Construct the path within the tarball of the files we want
sub_path="products/atmos/grib2/0p25"
declare -a pids=()
while [[ $cur_date -le $end_date ]]; do
    echo "Processing date: $cur_date"
    mm=$(date -d "$cur_date" +"%m")
    for cycle in 00 06 12 18; do
        echo "Processing cycle: $cycle"
        # I need the wildcard for all files in the sub_path.
        full_subpath=gfs.$cur_date/$cycle/$sub_path/*
        htar -xvf $root_dir/$cur_date$cycle/$tarball_name $full_subpath &
        pid=$!
        pids+=($pid)
        concurrent_jobs=$((concurrent_jobs + 1))
        if [[ $concurrent_jobs -ge $n_tasks ]]; then
            echo "Waiting for $concurrent_jobs jobs to finish..."
            for pid in "${pids[@]}"; do
                wait $pid
                pids=("${pids[@]/$pid}")
            done
            concurrent_jobs=0
        fi
    done
    cur_date=$(date -d "$cur_date + 1 day" +"%Y%m%d")
done

# Wait for any remaining jobs to finish
for pid in "${pids[@]}"; do
    wait $pid
done
