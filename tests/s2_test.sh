#!/usr/bin/env bash
# Tests for code/q4.rkt (S2: my-length, my-map, make-inserter, insert-if-short,
# print-insert-result).
#
# Run from anywhere (exit status 0 = every case passed):
#   bash tests/q4_tests.sh
#
# How it works
#  * Every expected value that is not an assignment example comes from an
#    INDEPENDENT reference implementation written in full `#lang racket`
#    (it uses length and map). The reference is first checked against the
#    four spec examples, whose expected output is hard-coded here.
#  * Direct-call cases: a copy of code/q4.rkt gets a prelude of input
#    generators plus one guarded `display` call per case (all cases in one
#    racket process, split by marker lines). Cases are written with `@name`;
#    `@` becomes nothing for the candidate and `ref-` for the reference.
#  * Stdin cases run print-insert-result in their own racket process.
#  * Everything happens in a temporary directory; code/ is never modified.
#  * Mutation check: mutated copies of q4.rkt must each fail some test.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Q4="$ROOT/code/q4.rkt"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/q4tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PASS_N=0
FAIL_N=0

report() { # name ok(0/1) [detail]
  if [ "$2" = 0 ]; then
    PASS_N=$((PASS_N + 1))
    echo "PASS $1"
  else
    FAIL_N=$((FAIL_N + 1))
    echo "FAIL $1"
    [ -n "$3" ] && printf '     %s\n' "$3"
  fi
}

check() { # name command...
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then report "$name" 0; else report "$name" 1; fi
}

# run_to SECONDS command... : run with a watchdog; stdin/stdout/stderr come from
# the caller's redirections.
run_to() {
  local secs=$1 pid wd rc
  shift
  "$@" <&0 &
  pid=$!
  ( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  wd=$!
  wait "$pid" 2>/dev/null
  rc=$?
  pkill -P "$wd" 2>/dev/null
  kill "$wd" 2>/dev/null
  wait "$wd" 2>/dev/null
  return $rc
}

# ---------------------------------------------------------------------------
# Shared prelude (valid in racket/base and in racket): input generators.
# ---------------------------------------------------------------------------
cat > "$TMP/prelude.rkt" <<'EOF'

(define (g-iota n)
  (let loop ((i n) (acc '()))
    (if (= i 0) acc (loop (- i 1) (cons i acc)))))
(define (g-chain d leaf)
  (let loop ((i d) (acc leaf))
    (if (= i 0) acc (loop (- i 1) (list acc)))))
(define (g-atoms w acc)
  (if (= w 0) acc (cons w (g-atoms (- w 1) acc))))
(define (g-wide d w)
  (let loop ((i d) (acc '()))
    (if (= i 0) acc (loop (- i 1) (g-atoms w (list acc))))))
(define (g-sublists n)
  (let loop ((i n) (acc '()))
    (if (= i 0)
        acc
        (loop (- i 1)
              (cons (if (= (modulo i 3) 0) '() (g-iota (modulo i 3))) acc)))))
EOF

# ---------------------------------------------------------------------------
# Independent reference implementation (full Racket, library length and map).
# ---------------------------------------------------------------------------
{
  cat <<'EOF'
#lang racket

(define (ref-ins x t ok?)
  (if (list? t)
      (let ([inner (map (lambda (e) (ref-ins x e ok?)) t)])
        (if (ok? (length t)) (cons x inner) inner))
      t))
(define (ref-make-inserter x ok?) (lambda (t) (ref-ins x t ok?)))
(define (ref-insert-if-short x t n) (ref-ins x t (lambda (len) (< len n))))
(define ref-my-length length)
(define ref-my-map map)
EOF
  cat "$TMP/prelude.rkt"
} > "$TMP/ref_head.rkt"

# ---------------------------------------------------------------------------
# Case registry
# ---------------------------------------------------------------------------
DN=(); DE=(); DX=()   # direct cases: name, expression, hard-coded expected
SN=(); SI=(); SR=(); SX=()  # stdin cases: name, raw input, ref expression, expected

add_direct() { DN+=("$1"); DE+=("$2"); DX+=("$3"); }
add_stdin() { SN+=("$1"); SI+=("$2"); SR+=("$3"); SX+=("$4"); }

while IFS='|' read -r cname cexpr cexp; do
  [ -z "$cname" ] && continue
  add_direct "$cname" "$cexpr" "$cexp"
done <<'EOF'
spec-1|(@insert-if-short 42 '((1 2) (3 4 5) (6) ()) 3)|((42 1 2) (3 4 5) (42 6) (42))
spec-2|(@insert-if-short 0 '(((1) 2) (3) ((4 5 6) ())) 3)|((0 (0 1) 2) (0 3) (0 (4 5 6) (0)))
spec-3|(@insert-if-short 7 '() 3)|(7)
spec-4|(@insert-if-short 7 '() 0)|()
len-empty|(@my-length '())
len-one-atom|(@my-length '(a))
len-mixed|(@my-length '(1 (2 3) ()))
len-single-sublist|(@my-length '((1 2 3)))
len-only-empty|(@my-length '(()))
len-nested-empties|(@my-length '((()) () (()) a))
len-flat-10000|(@my-length (g-iota 10000))
len-flat-100000|(@my-length (g-iota 100000))
len-depth-100|(@my-length (g-chain 100 '()))
len-wide-depth-100|(@my-length (g-wide 100 5))
map-inc|(@my-map (lambda (v) (+ v 1)) '(1 2 3))
map-empty|(@my-map (lambda (v) (+ v 1)) '())
map-identity|(@my-map (lambda (v) v) '((1) () 2))
map-wrap|(@my-map (lambda (v) (cons v '())) '(a b))
map-square-order|(@my-map (lambda (v) (* v v)) '(1 2 3 4 5))
map-sublists|(@my-map (lambda (v) (list v v)) '(1 () (2 3)))
map-no-descend|(@my-map (lambda (v) 0) '((1 2) (3 (4)) ()))
map-apply-order|(let ((log '())) (@my-map (lambda (v) (set! log (cons v log)) v) '(1 2 3)) log)
map-apply-once|(let ((c 0)) (@my-map (lambda (v) (set! c (+ c 1)) v) (g-iota 100)) c)
map-input-intact|(let ((l '(1 2 3))) (list (@my-map (lambda (v) (+ v 1)) l) l))
map-100000|(let ((r (@my-map (lambda (v) (+ v 1)) (g-iota 100000)))) (list (@my-length r) (car r) (cadr r)))
mk-lt3|((@make-inserter 42 (lambda (len) (< len 3))) '((1 2) (3 4 5) (6) ()))
mk-eq2|((@make-inserter 'z (lambda (len) (= len 2))) '((1 2) (3) () (4 (5 6))))
mk-always-true|((@make-inserter 'q (lambda (len) (>= len 0))) '(1 ()))
mk-always-false|((@make-inserter 'q (lambda (len) (< len 0))) '(1 (2)))
mk-empty-lt3|((@make-inserter 7 (lambda (len) (< len 3))) '())
mk-empty-false|((@make-inserter 7 (lambda (len) (< len 0))) '())
mk-even|((@make-inserter 'e (lambda (len) (= (modulo len 2) 0))) '((1 2) (3) () ((4 5) (6)) (7 8 9)))
mk-only-empty|((@make-inserter 'e (lambda (len) (= len 0))) '(() (1) (()) ((() ()))))
mk-ge3|((@make-inserter 'g (lambda (len) (>= len 3))) '((1 2 3) (4 5) (6 (7 8 9) 10)))
mk-original-length|((@make-inserter 'x (lambda (len) (< len 3))) '((1 2) (3)))
mk-reuse-one-inserter|(let ((ins (@make-inserter 'q (lambda (len) (< len 2))))) (list (ins '(1)) (ins '(1 2)) (ins '(1))))
mk-two-inserters|(let ((a (@make-inserter 'a (lambda (len) (< len 2)))) (b (@make-inserter 'b (lambda (len) (< len 2))))) (list (a '(1)) (b '(1)) (a '(1))))
mk-input-intact|(let ((l '((1) (2)))) (list ((@make-inserter 'x (lambda (len) #t)) l) l))
mk-number-x|((@make-inserter 5 (lambda (len) (< len 3))) '(a (b)))
mk-depth-100|((@make-inserter 'x (lambda (len) (< len 2))) (g-chain 100 '(1)))
mk-sublists-10000|((@make-inserter 'x (lambda (len) (< len 2))) (g-sublists 10000))
isf-atoms-short|(@insert-if-short 'a '(1 2) 3)
isf-atoms-equal-n|(@insert-if-short 'a '(1 2 3) 3)
isf-only-empty-n1|(@insert-if-short 'a '(()) 1)
isf-only-empty-n0|(@insert-if-short 'a '(()) 0)
isf-only-empty-n2|(@insert-if-short 'a '(()) 2)
isf-empty-top-n1|(@insert-if-short 'a '() 1)
isf-empty-top-n2|(@insert-if-short 'a '() 2)
isf-empty-top-n0|(@insert-if-short 'a '() 0)
isf-nested-empties-n0|(@insert-if-short 'a '(() (()) ((()))) 0)
isf-nested-empties-n1|(@insert-if-short 'a '(() (()) ((()))) 1)
isf-nested-empties-n2|(@insert-if-short 'a '(() (()) ((()))) 2)
isf-n-larger-than-all|(@insert-if-short 'a '((1) (2 3) ()) 100)
isf-atoms-only-n5|(@insert-if-short 'a '(1 2 3 b) 5)
isf-atoms-only-n4|(@insert-if-short 'a '(1 2 3 b) 4)
isf-empties-at-depths-n2|(@insert-if-short 'a '(() (()) ((() ()))) 2)
isf-empties-at-depths-n3|(@insert-if-short 'a '(() (()) ((() ()))) 3)
isf-original-length-n3|(@insert-if-short 'x '((1) (2)) 3)
isf-original-length-n2|(@insert-if-short 'x '((1) (2)) 2)
isf-x-number|(@insert-if-short 5 '(1 (2)) 3)
isf-x-symbol|(@insert-if-short 'five '(1 (2)) 3)
isf-x-equals-element|(@insert-if-short 1 '(1 (1)) 3)
isf-input-intact|(let ((l '((1) ()))) (list (@insert-if-short 'a l 2) l))
isf-symbol-elements|(@insert-if-short 0 '(a (b c) (d (e))) 3)
isf-n0-nonempty|(@insert-if-short 'a '(1 (2) ()) 0)
isf-deep-mixed|(@insert-if-short 'm '((((1 2) 3) ()) (4)) 3)
sc-chain-n3|(@insert-if-short 'x (g-chain 100 '()) 3)
sc-chain-n1|(@insert-if-short 'x (g-chain 100 '()) 1)
sc-chain-leaf3|(@insert-if-short 'x (g-chain 100 '(1 2 3)) 3)
sc-wide-100-w3-n5|(@insert-if-short 'x (g-wide 100 3) 5)
sc-wide-100-w3-n4|(@insert-if-short 'x (g-wide 100 3) 4)
sc-wide-100-w100-n102|(@insert-if-short 'x (g-wide 100 100) 102)
sc-wide-100-w100-n101|(@insert-if-short 'x (g-wide 100 100) 101)
sc-wide-100-w100-n50|(@insert-if-short 'x (g-wide 100 100) 50)
sc-flat-10000-n10001|(@insert-if-short 'x (g-iota 10000) 10001)
sc-flat-10000-n10000|(@insert-if-short 'x (g-iota 10000) 10000)
sc-sublists-10000-n3|(@insert-if-short 'x (g-sublists 10000) 3)
sc-sublists-10000-n2|(@insert-if-short 'x (g-sublists 10000) 2)
sc-sublists-10000-n10001|(@insert-if-short 'x (g-sublists 10000) 10001)
sc-depth-100-over-10000-sublists|(@insert-if-short 'x (g-chain 100 (g-sublists 10000)) 3)
sc-flat-100000|(let ((r (@insert-if-short 'x (g-iota 100000) 100001))) (list (@my-length r) (car r) (cadr r)))
EOF

while IFS='|' read -r cname craw cref cexp; do
  [ -z "$cname" ] && continue
  add_stdin "$cname" "$craw" "$cref" "$cexp"
done <<'EOF'
stdin-spec-1|42 ((1 2) (3 4 5) (6) ()) 3|(@insert-if-short 42 '((1 2) (3 4 5) (6) ()) 3)|((42 1 2) (3 4 5) (42 6) (42))
stdin-spec-2|0 (((1) 2) (3) ((4 5 6) ())) 3|(@insert-if-short 0 '(((1) 2) (3) ((4 5 6) ())) 3)|((0 (0 1) 2) (0 3) (0 (4 5 6) (0)))
stdin-spec-3|7 () 3|(@insert-if-short 7 '() 3)|(7)
stdin-spec-4|7 () 0|(@insert-if-short 7 '() 0)|()
stdin-symbol-x|a (1 (2)) 3|(@insert-if-short 'a '(1 (2)) 3)
stdin-number-x|5 (1 (2)) 3|(@insert-if-short 5 '(1 (2)) 3)
stdin-newline-separated|a\n(1\n (2))\n3\n|(@insert-if-short 'a '(1 (2)) 3)
stdin-extra-blanks|   a    (1    (2))    3   \n\n|(@insert-if-short 'a '(1 (2)) 3)
stdin-tabs-and-blank-lines|\n\n\ta \t(1 (2))\n\n 3|(@insert-if-short 'a '(1 (2)) 3)
stdin-no-trailing-newline|a (1 (2)) 3|(@insert-if-short 'a '(1 (2)) 3)
stdin-empty-n1|7 () 1|(@insert-if-short 7 '() 1)
stdin-only-empty|a (()) 1|(@insert-if-short 'a '(()) 1)
stdin-n-large|q (1 2 3) 10|(@insert-if-short 'q '(1 2 3) 10)
stdin-nested-empties|z ((((()))) ()) 2|(@insert-if-short 'z '((((()))) ()) 2)
stdin-n-equals-length|a (1 2 3) 3|(@insert-if-short 'a '(1 2 3) 3)
EOF

# Large stdin inputs built with seq/printf.
big_flat="a ($(seq 1 10000 | tr '\n' ' ')) 10001"
add_stdin "stdin-flat-10000" "$big_flat" "(@insert-if-short 'a (g-iota 10000) 10001)" ""
opens="$(printf '(%.0s' $(seq 1 101))"
closes="$(printf ')%.0s' $(seq 1 101))"
add_stdin "stdin-depth-100" "a ${opens}${closes} 3" "(@insert-if-short 'a (g-chain 100 '()) 3)" ""

# ---------------------------------------------------------------------------
# Static checks
# ---------------------------------------------------------------------------
echo "== static checks on code/q4.rkt"

check "line 1 is exactly '#lang racket/base'" \
  test "$(head -n 1 "$Q4")" = "#lang racket/base"

silent_out="$(racket "$Q4" 2>&1)"
if [ -z "$silent_out" ]; then
  report "racket code/q4.rkt prints nothing" 0
else
  report "racket code/q4.rkt prints nothing" 1 "got: $(printf '%s' "$silent_out" | head -c 200)"
fi

for name in my-length my-map make-inserter insert-if-short print-insert-result; do
  c="$(grep -cE "^\(define \($name[ )]" "$Q4")"
  if [ "$c" = 1 ]; then
    report "exactly one (define ($name ...) definition" 0
  else
    report "exactly one (define ($name ...) definition" 1 "count = $c"
  fi
done

stray="$(grep -vE '^(\(define |#lang racket/base$|;;|[[:space:]]|$)' "$Q4")"
if [ -z "$stray" ]; then
  report "every top-level form is a define" 0
else
  report "every top-level form is a define" 1 "$(printf '%s' "$stray" | head -n 2)"
fi

body="$(awk '/^\(define \(insert-if-short /{p=1} p{print} p&&/^$/{exit}' "$Q4")"
if printf '%s' "$body" | grep -qF 'make-inserter'; then
  report "insert-if-short body mentions make-inserter" 0
else
  report "insert-if-short body mentions make-inserter" 1
fi

code_only="$(sed 's/;.*//' "$Q4")"
tokens="$(printf '%s\n' "$code_only" | sed "s/[][(){}\`,'\"]/ /g" | tr -s '[:space:]' '\n')"
bad_found=""
for w in length append reverse map filter member memq list-ref list-tail set! \
         vector hash string do for list? symbol? number? equal? eqv? error void \
         abs min zero? set-car! set-cdr! for-each apply; do
  if printf '%s\n' "$tokens" | grep -Fxq -- "$w"; then bad_found="$bad_found $w"; fi
done
if printf '%s\n' "$tokens" | grep -Eq '^(vector|hash|string)[-?!a-z>*]*$|^for/|^vector-|^hash-|^string-'; then
  bad_found="$bad_found (vector/hash/string family)"
fi
if [ -z "$bad_found" ]; then
  report "no forbidden name appears as a whole token" 0
else
  report "no forbidden name appears as a whole token" 1 "found:$bad_found"
fi
if printf '%s\n' "$code_only" | grep -qF '#\'; then
  report "no #\\ character literal" 1
else
  report "no #\\ character literal" 0
fi
if printf '%s\n' "$code_only" | grep -qF '#:'; then
  report "no #: keyword" 1
else
  report "no #: keyword" 0
fi
if printf '%s\n' "$code_only" | grep -qF '"'; then
  report "no string literal in code" 1
else
  report "no string literal in code" 0
fi

# ---------------------------------------------------------------------------
# Reference run (expected values), checked against the hard-coded spec outputs
# ---------------------------------------------------------------------------
echo "== reference implementation"

batch_line() { # id expression
  printf '(begin (display "@@CASE %s") (newline) (with-handlers ((void (lambda (e) (display "ERROR") (newline)))) (display %s) (newline)))\n' "$1" "$2"
}

split_batch() { # batch.out outdir
  awk -v dir="$2" '
    /^@@CASE / { if (f != "") close(f); f = dir "/" $2; printf "" > f; next }
    f != "" { print > f }
  ' "$1"
}

mkdir -p "$TMP/ref_out" "$TMP/exp"
{
  cat "$TMP/ref_head.rkt"
  for i in "${!DN[@]}"; do
    e="${DE[$i]}"
    batch_line "d$i" "${e//@/ref-}"
  done
  for i in "${!SN[@]}"; do
    e="${SR[$i]}"
    batch_line "s$i" "${e//@/ref-}"
  done
} > "$TMP/ref_batch.rkt"
run_to 120 racket "$TMP/ref_batch.rkt" > "$TMP/ref_batch.out" 2> "$TMP/ref_batch.err" < /dev/null
split_batch "$TMP/ref_batch.out" "$TMP/ref_out"

fatal() {
  echo "FATAL: $1"
  echo "The reference implementation disagrees with the spec; no results are meaningful."
  exit 2
}

for i in "${!DN[@]}"; do
  id="d$i"
  [ -f "$TMP/ref_out/$id" ] || fatal "reference produced no output for ${DN[$i]}"
  [ "$(cat "$TMP/ref_out/$id")" = "ERROR" ] && fatal "reference errored on ${DN[$i]}"
  if [ -n "${DX[$i]}" ]; then
    printf '%s\n' "${DX[$i]}" > "$TMP/exp/$id"
    cmp -s "$TMP/exp/$id" "$TMP/ref_out/$id" || fatal "reference gives '$(cat "$TMP/ref_out/$id")' but the spec says '${DX[$i]}' for ${DN[$i]}"
  else
    cp "$TMP/ref_out/$id" "$TMP/exp/$id"
  fi
done
for i in "${!SN[@]}"; do
  id="s$i"
  [ -f "$TMP/ref_out/$id" ] || fatal "reference produced no output for ${SN[$i]}"
  [ "$(cat "$TMP/ref_out/$id")" = "ERROR" ] && fatal "reference errored on ${SN[$i]}"
  if [ -n "${SX[$i]}" ]; then
    printf '%s\n' "${SX[$i]}" > "$TMP/exp/$id"
    cmp -s "$TMP/exp/$id" "$TMP/ref_out/$id" || fatal "reference gives '$(cat "$TMP/ref_out/$id")' but the spec says '${SX[$i]}' for ${SN[$i]}"
  else
    cp "$TMP/ref_out/$id" "$TMP/exp/$id"
  fi
done
echo "reference agrees with the four spec examples (direct and stdin)"

# ---------------------------------------------------------------------------
# Dynamic suite: runs every direct and stdin case against a code file.
# ---------------------------------------------------------------------------
run_dynamic() { # code-file tag verbose
  local code=$1 tag=$2 verbose=$3 dir i id ok actual exp_s act_s
  dir="$TMP/run_$tag"
  mkdir -p "$dir/out"
  DYN_FAILS=0
  {
    cat "$code"
    cat "$TMP/prelude.rkt"
    for i in "${!DN[@]}"; do
      e="${DE[$i]}"
      batch_line "d$i" "${e//@/}"
    done
  } > "$dir/batch.rkt"
  run_to 120 racket "$dir/batch.rkt" > "$dir/batch.out" 2> "$dir/batch.err" < /dev/null
  split_batch "$dir/batch.out" "$dir/out"
  for i in "${!DN[@]}"; do
    id="d$i"
    ok=1
    if [ -f "$dir/out/$id" ] && cmp -s "$dir/out/$id" "$TMP/exp/$id"; then ok=0; fi
    if [ "$ok" != 0 ]; then
      DYN_FAILS=$((DYN_FAILS + 1))
      if [ "$verbose" = 1 ]; then
        exp_s="$(head -c 150 "$TMP/exp/$id")"
        if [ -f "$dir/out/$id" ]; then act_s="$(head -c 150 "$dir/out/$id")"; else act_s="(no output)"; fi
        report "${DN[$i]}" 1 "expected: $exp_s  actual: $act_s"
      fi
    elif [ "$verbose" = 1 ]; then
      report "${DN[$i]}" 0
    fi
  done
  for i in "${!SN[@]}"; do
    id="s$i"
    { cat "$code"; printf '\n(print-insert-result)\n'; } > "$dir/$id.rkt"
    printf '%b' "${SI[$i]}" > "$dir/$id.in"
    run_to 60 racket "$dir/$id.rkt" > "$dir/$id.out" 2> "$dir/$id.err" < "$dir/$id.in"
    if cmp -s "$dir/$id.out" "$TMP/exp/$id"; then
      [ "$verbose" = 1 ] && report "${SN[$i]}" 0
    else
      DYN_FAILS=$((DYN_FAILS + 1))
      if [ "$verbose" = 1 ]; then
        report "${SN[$i]}" 1 "expected: $(head -c 150 "$TMP/exp/$id")  actual: $(head -c 150 "$dir/$id.out")"
      fi
    fi
  done
}

echo "== direct-call and stdin cases (${#DN[@]} direct, ${#SN[@]} stdin)"
run_dynamic "$Q4" main 1

# ---------------------------------------------------------------------------
# Timing: n, 2n, 4n
# ---------------------------------------------------------------------------
echo "== timing (best of 3 runs inside one process; milliseconds)"
TN=250000
time_kind() { # label data-expression-with-SZ
  local label=$1 dexpr=$2 f="$TMP/time_$1.rkt" mult sz t1 t2 t4
  {
    cat "$Q4"
    cat "$TMP/prelude.rkt"
    cat <<'EOF'
(define (g-ms thunk)
  (let ((t0 (current-inexact-milliseconds)))
    (thunk)
    (- (current-inexact-milliseconds) t0)))
(define (g-best data)
  (let ((run (lambda () (g-ms (lambda () (my-length (insert-if-short 0 data 1000000000)))))))
    (let* ((a (run)) (b (run)) (c (run))) (min a b c))))
(define (g-show v) (display (inexact->exact (round v))) (newline))
EOF
    for mult in 1 2 4; do
      sz=$((TN * mult))
      printf '(g-show (g-best %s))\n' "${dexpr//SZ/$sz}"
    done
  } > "$f"
  run_to 120 racket "$f" > "$TMP/time_$label.out" 2> "$TMP/time_$label.err" < /dev/null
  t1="$(sed -n 1p "$TMP/time_$label.out")"
  t2="$(sed -n 2p "$TMP/time_$label.out")"
  t4="$(sed -n 3p "$TMP/time_$label.out")"
  echo "  $label: n=$TN ${t1}ms, 2n ${t2}ms, 4n ${t4}ms"
  if ! [[ $t1 =~ ^[0-9]+$ && $t2 =~ ^[0-9]+$ && $t4 =~ ^[0-9]+$ ]]; then
    report "timing $label" 1 "no timings produced"
  elif [ "$t1" -ge 10000 ] || [ "$t2" -ge 10000 ] || [ "$t4" -ge 10000 ]; then
    report "timing $label" 1 "a run took 10 seconds or more"
  elif [ "$t4" -gt $((8 * t1 + 200)) ]; then
    report "timing $label" 1 "4n run (${t4}ms) is more than 8 x n run (${t1}ms) + 200ms"
  else
    report "timing $label" 0
  fi
}
time_kind flat-atoms "(g-iota SZ)"
time_kind flat-sublists "(g-sublists SZ)"
time_kind deep-chain "(g-chain SZ '())"

# ---------------------------------------------------------------------------
# Mutation check
# ---------------------------------------------------------------------------
echo "== mutation check (every mutant must make some test fail)"

mutate() { # file old new
  perl -0777 -e '
    my ($f, $a, $b) = @ARGV;
    open(my $in, "<", $f) or die "open: $!";
    local $/;
    my $s = <$in>;
    close $in;
    my $i = index($s, $a);
    die "pattern not found\n" if $i < 0;
    substr($s, $i, length($a)) = $b;
    open(my $out, ">", $f) or die "open: $!";
    print $out $s;
    close $out;
  ' "$1" "$2" "$3"
}

MUT_CAUGHT=0
MUT_TOTAL=0
run_mutant() { # label old new
  local label=$1 f="$TMP/mutant_$1.rkt"
  MUT_TOTAL=$((MUT_TOTAL + 1))
  cp "$Q4" "$f"
  if ! mutate "$f" "$2" "$3" 2>"$TMP/mutate.err" || cmp -s "$f" "$Q4"; then
    report "mutant $label could not be built" 1 "$(cat "$TMP/mutate.err")"
    return
  fi
  run_dynamic "$f" "m_$label" 0
  if [ "$DYN_FAILS" -gt 0 ]; then
    MUT_CAUGHT=$((MUT_CAUGHT + 1))
    report "mutant $label caught ($DYN_FAILS failing cases)" 0
  else
    report "mutant $label SURVIVED (no test failed)" 1
  fi
}

run_mutant "lt-to-le-in-insert-if-short" '(< len n)' '(<= len n)'
run_mutant "n-off-by-one" '(< len n)' '(< len (- n 1))'
run_mutant "no-final-newline" $'(display (insert-if-short x lst n))\n    (newline)' $'(display (insert-if-short x lst n))\n    (display "")'
run_mutant "my-map-base-case-dropped" $'    ((null? lst) \'())\n' ''
run_mutant "length-measured-after-insertion" '((len-ok? (my-length tree))' '((len-ok? (my-length (cons x tree)))'
run_mutant "my-length-counts-by-two" '(+ count 1)' '(+ count 2)'
run_mutant "x-inserted-twice" '(cons x new-items)' '(cons x (cons x new-items))'
run_mutant "sublists-not-processed" '(my-map process tree)' '(my-map (lambda (item) item) tree)'
run_mutant "empty-list-treated-as-atom" '(or (pair? tree) (null? tree))' '(pair? tree)'
run_mutant "read-order-swapped" $'(let* ((x (read))\n         (lst (read))' $'(let* ((lst (read))\n         (x (read))'
run_mutant "my-map-applies-in-reverse-order" '(cons (f (car lst)) (my-map f (cdr lst)))' '(let ((rest-result (my-map f (cdr lst)))) (cons (f (car lst)) rest-result))'
run_mutant "my-map-drops-last-pair" '(my-map f (cdr lst))' '(my-map f (cdr (cdr lst)))'

# ---------------------------------------------------------------------------
echo "== summary"
echo "mutants caught: $MUT_CAUGHT of $MUT_TOTAL"
echo "SUMMARY: $PASS_N passed, $FAIL_N failed"
[ "$FAIL_N" = 0 ]
