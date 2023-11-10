#!/usr/bin/env bash

# --------------------------------------------------------------------------------------------------
# Copyright (c) 2006-2023, Knut Reinert & Freie Universität Berlin
# Copyright (c) 2016-2023, Knut Reinert & MPI für molekulare Genetik
# This file may be used, modified and/or redistributed under the terms of the 3-clause BSD-License
# shipped with this file and also available at: https://github.com/seqan/raptor/blob/main/LICENSE.md
# --------------------------------------------------------------------------------------------------

set -Eeuo pipefail

# Input and Output
RAPTOR_BINARY="/srv/public/leonard/raptor/build/bin/raptor"
INPUT_DIR="/srv/data/seiler/simulation" # output directory of simulation. the directory that contains the BIN_COUNT directory
OUTPUT_DIR="/srv/data/leonard/test_run" # benchmark out will be generated here

mkdir -p ${OUTPUT_DIR} # Create OUTPUT_DIR if it does not exist.

# Raptor configuration
KMER_SIZE=32
WINDOW_SIZE=${KMER_SIZE}
NUM_THREADS=32
MAXIMUM_FPR=0.05
RELAXED_FPR=0.3
NUM_HASHES=2

# Default read configuration
QUERY_LENGTH=250
QUERY_ERRORS=2

# Max and min bin count
# 2^10 -> 1024
# 2^20 -> 1048576
MIN_EXPONENT=10
MAX_EXPONENT=13

# Sanity checks
if ! [[ -d ${OUTPUT_DIR} ]]; then
    echo "Directory ${OUTPUT_DIR} does not exist. Exiting."
    exit 1
fi

if ! [[ -s ${RAPTOR_BINARY} ]]; then
    echo "Executable ${RAPTOR_BINARY} does not exist. Exiting."
    exit 1
fi

if ! ${RAPTOR_BINARY} --help &> /dev/null; then
    echo "Executable ${RAPTOR_BINARY} cannot be run. Exiting."
    exit 1
fi

for EXPONENT in $(seq ${MIN_EXPONENT} 1 ${MAX_EXPONENT}); do
    BIN_COUNT=$(bc <<< "2^${EXPONENT}")

    FILENAMES_FILE=${INPUT_DIR}/${BIN_COUNT}.filenames
    QUERY_FILE=${INPUT_DIR}/${BIN_COUNT}/reads_e${QUERY_ERRORS}_${QUERY_LENGTH}/all.fastq

    if ! [[ -s ${FILENAMES_FILE} ]]; then
        echo "File ${FILENAMES_FILE} does not exist or is empty. Exiting."
        exit 1
    fi
    if ! [[ -s ${QUERY_FILE} ]]; then
        echo "File ${QUERY_FILE} does not exist or is empty. Exiting."
        exit 1
    fi
done

# Runs for each bin count: 1024 [10], 2048 [11], 4096 [12], 8192 [13]
for EXPONENT in $(seq ${MIN_EXPONENT} 1 ${MAX_EXPONENT}); do
    BIN_COUNT=$(bc <<< "2^${EXPONENT}")

    echo "[$(date +"%Y-%m-%d %T")] Running raptor layout for ${BIN_COUNT} bins."
    LAYOUT_FILE=${OUTPUT_DIR}/${BIN_COUNT}.layout
    LAYOUT_TIME=${OUTPUT_DIR}/${BIN_COUNT}.layout.time
    # Raptor layout doesn't provide `--timing-output`, so we use /usr/bin/time with a custom format
    /usr/bin/time -o ${LAYOUT_TIME} -f "wall_clock_time_in_seconds\tpeak_memory_usage_in_kibibytes\n%e\t%M" \
        ${RAPTOR_BINARY} layout --input ${INPUT_DIR}/${BIN_COUNT}.filenames \
                                --output ${LAYOUT_FILE} \
                                --kmer ${KMER_SIZE} \
                                --fpr ${MAXIMUM_FPR} \
                                --relaxed-fpr ${RELAXED_FPR} \
                                --hash ${NUM_HASHES} \
                                --disable-estimate-union \
                                --disable-rearrangement \
                                --threads ${NUM_THREADS}

    echo "[$(date +"%Y-%m-%d %T")] Running raptor build for ${BIN_COUNT} bins."
    INDEX_FILE=${OUTPUT_DIR}/${BIN_COUNT}.index
    INDEX_TIME=${OUTPUT_DIR}/${BIN_COUNT}.index.time
    ${RAPTOR_BINARY} build --input ${LAYOUT_FILE} \
                           --output ${INDEX_FILE} \
                           --window ${WINDOW_SIZE} \
                           --quiet \
                           --timing-output ${INDEX_TIME} \
                           --threads ${NUM_THREADS}

    echo "[$(date +"%Y-%m-%d %T")] Running raptor search for ${BIN_COUNT} bins."
    RESULT_FILE=${OUTPUT_DIR}/${BIN_COUNT}.out
    RESULT_TIME=${OUTPUT_DIR}/${BIN_COUNT}.out.time
    ${RAPTOR_BINARY} search --index ${INDEX_FILE} \
                            --query ${INPUT_DIR}/${BIN_COUNT}/reads_e${QUERY_ERRORS}_${QUERY_LENGTH}/all.fastq \
                            --output ${RESULT_FILE} \
                            --error ${QUERY_ERRORS} \
                            --query_length ${QUERY_LENGTH} \
                            --quiet \
                            --timing-output ${RESULT_TIME} \
                            --threads ${NUM_THREADS}
done

# Possible extensions:
# * Measure energy consumption
# * Run raptor prepare as first step (toggleable)
# * Parameter sweeps
# * Other tools
