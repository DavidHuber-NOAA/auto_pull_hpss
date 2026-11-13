#!/bin/bash

# This script moves PGB files from the COM structure to a single desitnation directory.
# Usage: move_pgbs.sh <source_directory> <destination_directory> <start_date> <end_date>

usage() {
    echo "Usage: $0 <source_directory> <destination_directory> <start_date> <end_date>"
    echo "Example: $0 /path/to/source /path/to/destination 20230101 20230131"
    exit 1
}

if [ "$#" -ne 4 ]; then
    usage
fi

source_dir="$1"
destination_dir="$2"
start_date="$3"
end_date="$4"

# Check if the source directory exists
if [ ! -d "$source_dir" ]; then
    echo "Source directory does not exist: $source_dir"
    usage
    exit 1
fi

# Check if the destination directory exists, if not create it
mkdir -p "$destination_dir"
err=$?
if [ $err -ne 0 ]; then
    echo "Failed to create destination directory: $destination_dir"
    usage
    exit 1
fi

# Start and end date should be in YYYYMMDD format
if [[ ! $start_date =~ ^[0-9]{8}$ ]] || [[ ! $end_date =~ ^[0-9]{8}$ ]]; then
    echo "Start date and end date must be in YYYYMMDD format."
    usage
    exit 1
fi
set -eu -o pipefail

cur_date=${start_date}
while [[ ${cur_date} -le ${end_date} ]]; do
    for cycle in 00 06 12 18; do
        source_path="${source_dir}/gfs.${cur_date}/${cycle}/products/atmos/grib2/0p25"
        fname_root="gfs.t${cycle}z.pres_a.0p25.f"
        aname_root="gfs.t${cycle}z.pres_a.0p25.analysis"
        fname_ext=".grib2"
        flist=$(find "${source_path}/${fname_root}"*"${fname_ext}" "${source_path}/${aname_root}"*"${fname_ext}" -type f -print) || true
        # make flist an array
        flist=(${flist})
        echo "${flist[@]}"
        for f in "${flist[@]}"; do
            if [[ -f "$f" ]]; then
                # Extract the forecast hour from the filename
                forecast_hour=$(basename "$f" | sed -E "s/${fname_root}([0-9]{3})${fname_ext}/\1/" || true)
                # If the forecast hour is empty, it might be an analysis file, so we can set it to -1
                if [[ "${f}" == *"${aname_root}"* ]]; then
                    forecast_hour=-1
                    ff=-1
                elif [[ -n "${forecast_hour}" ]]; then
                    ff=$((10#$forecast_hour))  # Convert to decimal to avoid octal interpretation
                else
                    echo "Could not extract forecast hour from filename: $f"
                    exit 2
                fi

                if [[ ${ff} -ge 0 ]]; then
                    # The new filename follows the convention pgbf<forecast_hour>.gfs.YYYYMMDDcycle.grib2
                    # With forecast hour padded to 2 digits
                    new_fhr=$(printf "%02d" "$ff")
                    new_filename="pgbf${new_fhr}.gfs.${cur_date}${cycle}.grib2"
                else
                    # For analysis files, we can use pgbf00 as the forecast hour
                    new_filename="pgbanl.gfs.${cur_date}${cycle}.grib2"
                fi
                # Fail if the file already exists
                if [[ -f "${destination_dir}/${new_filename}" ]]; then
                    echo "File already exists in destination: ${destination_dir}/${new_filename}"
                    exit 3
                fi
                mv "$f" "${destination_dir}/${new_filename}"
            fi
        done
    done
    cur_date=$(date -d "${cur_date} + 1 day" +"%Y%m%d")
done
