# Access-log analysis -- ported from the analyze-access-logs task: for each
# access log, report total requests, unique IPs, the top-3 URLs, and 404s
# (same pipeline as the task's solve.sh: $1=IP, $7=url, $9=status).
# Scaled for PaSh across many files (MANIFEST) x ENTRIES; the offloaded unit is
# one clean per-file pipeline `cat file | pure_func > out`.
#
#   IN/OUT/MANIFEST/PASH_TOP as usual; ENTRIES scales the workload.

IN=${IN:-$PASH_TOP/evaluation/benchmarks/agent/inputs/access/}
OUT=${OUT:-$PASH_TOP/evaluation/benchmarks/agent/outputs/}
MANIFEST=${MANIFEST:-$PASH_TOP/evaluation/benchmarks/agent/access.txt}
ENTRIES=${ENTRIES:-1}

echo "ENTRIES=$ENTRIES"

mkdir -p "$OUT"

# One access log on stdin -> the report block.
pure_func() {
    tmp=$(mktemp)
    cat > "$tmp"
    total=$(wc -l < "$tmp")
    uips=$(awk '{print $1}' "$tmp" | sort -u | wc -l)
    e404=$(awk '$9=="404"' "$tmp" | wc -l)
    top=$(awk '{print $7}' "$tmp" | sort | uniq -c | sort -nr | head -3)
    printf 'Total requests: %s\n' "$total"
    printf 'Unique IP addresses: %s\n' "$uips"
    printf 'Top 3 URLs:\n'
    printf '%s\n' "$top" | awk '{printf "  %s: %d\n", $2, $1}'
    printf '404 errors: %s\n' "$e404"
    rm -f "$tmp"
}
export -f pure_func

# Simulate agent thinking/reasoning time
sleep 454

for fname in $(cat "$MANIFEST"); do
    for i in $(seq 1 "$ENTRIES"); do
        cat "${IN}${fname}" | pure_func > "${OUT}report.${fname}.${i}.stdout"
    done
done

echo "Done"
