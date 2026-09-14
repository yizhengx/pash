#!/bin/bash
# (Re)sync the locally-generated input datasets to S3 so the serverless runs can
# read them. inputs.sh already uploads as it generates; this is a convenience to
# push whatever is present locally.  Pass a dataset to limit it.
#
#   ./upload.sh            # all datasets present under inputs/
#   ./upload.sh logs       # only inputs/logs/      -> agent/inputs/logs/
#   ./upload.sh intrusion  # only inputs/intrusion/ -> agent/inputs/intrusion/
cd "$(dirname "$0")" || exit 1
[ -z "$PASH_TOP" ]   && { echo "PASH_TOP not set, maybe $(git rev-parse --show-toplevel)?"; exit 1; }
[ -z "$AWS_BUCKET" ] && { echo "AWS_BUCKET not set"; exit 1; }

BENCHMARK_DIR="$PASH_TOP/evaluation/benchmarks/agent"
S3_BASE="s3://$AWS_BUCKET/agent/inputs"

case "${1:-all}" in
    logs)      datasets=(logs) ;;
    intrusion) datasets=(intrusion) ;;
    all)       datasets=(logs intrusion) ;;
    *) echo "unknown dataset: $1 (use logs|intrusion|all)"; exit 2 ;;
esac

for d in "${datasets[@]}"; do
    src="$BENCHMARK_DIR/inputs/$d"
    if [ ! -d "$src" ] || [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
        echo "skip $d: nothing at $src"
        continue
    fi
    echo "Uploading $src/ to $S3_BASE/$d/"
    aws s3 sync "$src/" "$S3_BASE/$d/" --exclude '*' --include '*.log' --no-progress | tail -2
done
echo "done"
