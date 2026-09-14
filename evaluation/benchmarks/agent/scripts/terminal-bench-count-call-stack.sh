# Call-stack analysis -- ported from the count-call-stack task (shell pipeline,
# as its instruction requires). Each trace is a digits-only header line followed
# by "\t in <frame>" lines; group traces by their top-3 frames and report:
#   Found <N> stack traces / unique call sites / analyzed + top-10 call sites.
# Scaled for PaSh across many files (MANIFEST) x ENTRIES; offloaded unit is one
# clean per-file pipeline `cat file | pure_func > out`.
#
#   IN/OUT/MANIFEST/PASH_TOP as usual; ENTRIES scales the workload.

IN=${IN:-$PASH_TOP/evaluation/benchmarks/agent/inputs/callstack/}
OUT=${OUT:-$PASH_TOP/evaluation/benchmarks/agent/outputs/}
MANIFEST=${MANIFEST:-$PASH_TOP/evaluation/benchmarks/agent/callstack.txt}
ENTRIES=${ENTRIES:-1}

echo "ENTRIES=$ENTRIES"

mkdir -p "$OUT"

# One stack log on stdin -> the report block.
pure_func() {
    tmp=$(mktemp); sigs=$(mktemp)
    cat > "$tmp"
    # One line per trace = its top-3 frames joined by @@@ (frame = text after "in ").
    awk '
        function flush(){ if(nf>0){ s=fr[1]; for(k=2;k<=3 && k<=nf;k++) s=s "@@@" fr[k]; print s } }
        /^[0-9]+$/ { if(started) flush(); started=1; nf=0; next }
        /^[[:space:]]*in / { if(nf<3){ line=$0; sub(/^[[:space:]]*in[[:space:]]+/,"",line); nf++; fr[nf]=line } next }
        END { if(started) flush() }
    ' "$tmp" > "$sigs"

    total=$(grep -cE '^[0-9]+$' "$tmp")
    analyzed=$(wc -l < "$sigs")
    uniqc=$(sort "$sigs" | uniq | wc -l)
    printf 'Found %s stack traces\n' "$total"
    printf 'Number of unique call sites (based on top 3 frames): %s\n' "$uniqc"
    printf 'Total stack traces analyzed: %s\n\n' "$analyzed"
    printf 'Most common call sites:\n'
    sort "$sigs" | uniq -c | sort -rn | head -10 | awk '
        { match($0,/^ *[0-9]+ /); cnt=substr($0,1,RLENGTH); gsub(/ /,"",cnt); rest=substr($0,RLENGTH+1);
          n=split(rest, fm, "@@@");
          printf "\n%d. Count: %s\n", ++rank, cnt;
          for(k=1;k<=n;k++) printf "   Frame %d: %s\n", k, fm[k];
        }'
    rm -f "$tmp" "$sigs"
}
export -f pure_func

# Simulate agent thinking/reasoning time
sleep 150

for fname in $(cat "$MANIFEST"); do
    for i in $(seq 1 "$ENTRIES"); do
        cat "${IN}${fname}" | pure_func > "${OUT}callsites.${fname}.${i}.stdout"
    done
done

echo "Done"
