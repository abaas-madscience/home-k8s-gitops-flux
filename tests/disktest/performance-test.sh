#!/bin/bash
set -euo pipefail

TEST_DIR="/data"
TEST_FILE="$TEST_DIR/testfile"
BLOCK_SIZE="4k"
SIZE="512M"
RUNTIME="30s"
NUMJOBS=4

echo "Starting performance test on: $TEST_DIR"

mkdir -p "$TEST_DIR"

echo "Running fio test (random read/write with $BLOCK_SIZE block size, $SIZE file)..."

fio --name=randrw-test \
    --directory="$TEST_DIR" \
    --filename="$TEST_FILE" \
    --size="$SIZE" \
    --bs="$BLOCK_SIZE" \
    --rw=randrw \
    --rwmixread=50 \
    --ioengine=libaio \
    --iodepth=64 \
    --numjobs="$NUMJOBS" \
    --runtime="$RUNTIME" \
    --time_based \
    --group_reporting \
    --output-format=json \
    --output=/tmp/fio-output.json
    
echo "==== Performance Summary ===="
jq -r '
  .jobs[] |
  "Job: \(.job)\n" +
  "  Read IOPS     : \(.read.iops | floor)\n" +
  "  Write IOPS    : \(.write.iops | floor)\n" +
  "  Read BW       : \((.read.bw_bytes / 1024 / 1024) | floor) MB/s\n" +
  "  Write BW      : \((.write.bw_bytes / 1024 / 1024) | floor) MB/s"
' /tmp/fio-output.json


# Optional cleanup
rm -f "$TEST_FILE"
