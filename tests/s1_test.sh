#!/usr/bin/env bash
# Test harness for S1 "Binary Tree Traversals" (code/q3.rkt).
# Usage: bash tests/s1_test.sh /absolute/path/to/code/q3.rkt
#
# - Never modifies the solution: every case works on a temporary copy that gets
#   the tree definition and ONE call appended, then runs with `racket`.
# - Expected outputs come from an independent reference implementation written
#   in Python (embedded below, array-based and iterative), except the spec
#   examples whose expected text is copied verbatim from the assignment prompt
#   (the reference is also checked against them).
# - Exit status 0 only if every check and every case passes.

SOL="$1"
if [ -z "$SOL" ] || [ "${SOL#/}" = "$SOL" ] || [ ! -f "$SOL" ]; then
  echo "usage: bash tests/s1_test.sh /absolute/path/to/code/q3.rkt" >&2
  exit 2
fi
for tool in racket python3 timeout cmp; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "required tool missing: $tool" >&2
    exit 2
  fi
done

WORK=$(mktemp -d "${TMPDIR:-/tmp}/s1_test.XXXXXX") || exit 2
WORK=$(cd "$WORK" && pwd)
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
MISSING=0
WARN=0
LIMIT=30

pass() { PASS=$((PASS + 1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL $1"; }
missing() { MISSING=$((MISSING + 1)); echo "MISSING $1"; }
warn() { WARN=$((WARN + 1)); echo "WARN $1"; }
now() { python3 -c 'import time; print(time.time())'; }

NAMES="print-inorder print-all-traversals print-height-and-leaves inorder-onto preorder-onto postorder-onto tree-height count-leaves"

# ---------------------------------------------------------------- static checks
echo "== static checks on $SOL"

if [ "$(head -n 1 "$SOL")" = "#lang racket/base" ]; then
  pass "static: line 1 is exactly '#lang racket/base'"
else
  fail "static: line 1 is exactly '#lang racket/base'"
fi

racket "$SOL" >"$WORK/load.out" 2>"$WORK/load.err"
load_status=$?
if [ "$load_status" -eq 0 ] && [ ! -s "$WORK/load.out" ] && [ ! -s "$WORK/load.err" ]; then
  pass "static: loading the file prints nothing (stdout and stderr empty, exit 0)"
else
  fail "static: loading the file prints nothing (exit $load_status, stdout $(wc -c <"$WORK/load.out" | tr -d ' ') bytes, stderr $(wc -c <"$WORK/load.err" | tr -d ' ') bytes)"
fi

for name in $NAMES; do
  n=$(grep -cF "(define ($name " "$SOL")
  if [ "$n" -eq 1 ]; then
    pass "static: $name defined exactly once"
  elif [ "$n" -eq 0 ]; then
    missing "static: $name is not defined"
  else
    fail "static: $name defined $n times"
  fi
done

# Forbidden-name scan (informational). Comments are stripped first (line numbers kept).
sed 's/;.*//' "$SOL" >"$WORK/nocomments.rkt"
hits=$(grep -nwE 'append|length|reverse|map|filter|member|memq|list-ref|list-tail|set!|list\?|symbol\?|number\?|equal\?|void|error' "$WORK/nocomments.rkt")
if [ -n "$hits" ]; then
  while IFS= read -r line; do warn "forbidden-name hit (review): $line"; done <<EOF
$hits
EOF
fi
hits=$(grep -nF '#\' "$WORK/nocomments.rkt")
if [ -n "$hits" ]; then
  while IFS= read -r line; do warn "char-literal text '#\\' (review): $line"; done <<EOF
$hits
EOF
fi
hits=$(grep -nF '#:' "$WORK/nocomments.rkt")
if [ -n "$hits" ]; then
  while IFS= read -r line; do warn "keyword text '#:' (review): $line"; done <<EOF
$hits
EOF
fi

# ------------------------------------------------- case generation (reference)
CASES="$WORK/cases"
python3 - "$CASES" <<'PYEOF'
import os
import sys

out = sys.argv[1]
os.makedirs(out)


# ---- tree as arrays: V[i] value string, L[i]/R[i] child index or -1 -------
class Tree(object):
    def __init__(self, V, L, R, root):
        self.V, self.L, self.R, self.root = V, L, R, root


def parse(text):
    toks = text.replace("(", " ( ").replace(")", " ) ").split()
    V, L, R = [], [], []
    pos = [0]

    def tree():
        if toks[pos[0]] != "(":
            raise ValueError("expected ( in " + text)
        pos[0] += 1
        if toks[pos[0]] == ")":
            pos[0] += 1
            return -1
        v = toks[pos[0]]
        pos[0] += 1
        idx = len(V)
        V.append(v)
        L.append(-1)
        R.append(-1)
        L[idx] = tree()
        R[idx] = tree()
        if toks[pos[0]] != ")":
            raise ValueError("expected ) in " + text)
        pos[0] += 1
        return idx

    root = tree()
    if pos[0] != len(toks):
        raise ValueError("trailing tokens in " + text)
    return Tree(V, L, R, root)


def serialize(t):
    parts = []
    st = [t.root]
    while st:
        x = st.pop()
        if isinstance(x, str):
            parts.append(x)
        elif x == -1:
            parts.append("()")
        else:
            parts.append("(" + t.V[x] + " ")
            st.append(")")
            st.append(t.R[x])
            st.append(" ")
            st.append(t.L[x])
    return "".join(parts)


# ---- independent reference implementation (iterative, never recursive) ----
def ref_inorder(t):
    res, st, n = [], [], t.root
    while st or n != -1:
        while n != -1:
            st.append(n)
            n = t.L[n]
        n = st.pop()
        res.append(t.V[n])
        n = t.R[n]
    return res


def ref_preorder(t):
    res = []
    st = [t.root] if t.root != -1 else []
    while st:
        n = st.pop()
        res.append(t.V[n])
        if t.R[n] != -1:
            st.append(t.R[n])
        if t.L[n] != -1:
            st.append(t.L[n])
    return res


def ref_postorder(t):
    # reverse of the (node, right, left) order
    res = []
    st = [t.root] if t.root != -1 else []
    while st:
        n = st.pop()
        res.append(t.V[n])
        if t.L[n] != -1:
            st.append(t.L[n])
        if t.R[n] != -1:
            st.append(t.R[n])
    res.reverse()
    return res


def ref_height(t):
    level = [t.root] if t.root != -1 else []
    h = 0
    while level:
        h += 1
        nxt = []
        for n in level:
            if t.L[n] != -1:
                nxt.append(t.L[n])
            if t.R[n] != -1:
                nxt.append(t.R[n])
        level = nxt
    return h


def ref_leaves(t):
    count = 0
    for i in range(len(t.V)):  # arrays hold exactly the reachable nodes
        if t.L[i] == -1 and t.R[i] == -1:
            count += 1
    return count


def fmt(items):
    return "(" + " ".join(items) + ")"


# ---- hand-picked trees (canonical text: single spaces) --------------------
SPEC = [
    ("t1", "(4 (2 (1 () ()) (3 () ())) (6 (5 () ()) (7 () ())))"),
    ("t2", "(1 () (2 () (3 () ())))"),
    ("t3", "(a (b () ()) (c () ()))"),
    ("empty", "()"),
]
EDGE = [
    ("single-number", "(5 () ())"),
    ("single-symbol", "(x () ())"),
    ("root-left-child-only", "(1 (2 () ()) ())"),
    ("root-right-child-only", "(1 () (2 () ()))"),
    ("left-only-chain-5", "(1 (2 (3 (4 (5 () ()) ()) ()) ()) ())"),
    ("right-only-chain-5", "(1 () (2 () (3 () (4 () (5 () ())))))"),
    ("deepest-in-left", "(1 (2 (3 (4 () ()) ()) ()) (5 () ()))"),
    ("deepest-in-right", "(1 (5 () ()) (2 () (3 () (4 () ()))))"),
    ("mixed-numbers-symbols", "(m (3 (a () ()) (7 () ())) (z () (q (4 () ()) ())))"),
    ("zero-negative-repeated", "(0 (-1 (0 () ()) (-1 () ())) (0 (7 () ()) (7 () (-5 () ()))))"),
    ("one-child-nodes-at-depths", "(1 (2 () (3 () ())) (4 (5 () ()) ()))"),
    ("lopsided-bush", "(8 (4 (2 (1 () ()) ()) (6 () (7 () ()))) (12 (10 (9 () ()) (11 () ())) ()))"),
]

# Spec expected texts, copied verbatim from the assignment prompt.
SPEC_EXPECTED = {
    ("t1", "print-inorder"): "(1 2 3 4 5 6 7)\n",
    ("t1", "print-all-traversals"): "(1 2 3 4 5 6 7)\n(4 2 1 3 6 5 7)\n(1 3 2 5 7 6 4)\n",
    ("t1", "print-height-and-leaves"): "(3 4)\n",
    ("t2", "print-all-traversals"): "(1 2 3)\n(1 2 3)\n(3 2 1)\n",
    ("t2", "print-height-and-leaves"): "(3 1)\n",
    ("t3", "print-all-traversals"): "(b a c)\n(a b c)\n(b c a)\n",
    ("t3", "print-height-and-leaves"): "(2 2)\n",
    ("empty", "print-inorder"): "()\n",
    ("empty", "print-all-traversals"): "()\n()\n()\n",
    ("empty", "print-height-and-leaves"): "(0 0)\n",
}

counter = [0]
refcheck_failures = []


def emit(name, fn, tree_text, call_text, expected, kind):
    counter[0] += 1
    d = os.path.join(out, "%05d" % counter[0])
    os.makedirs(d)
    files = {
        "name": name,
        "fn": fn,
        "tree": "(define t '" + tree_text + ")\n",
        "call": call_text + "\n",
        "kind": kind,
    }
    for k, v in files.items():
        with open(os.path.join(d, k), "w") as f:
            f.write(v)
    with open(os.path.join(d, "expected"), "w") as f:
        f.write(expected)


def all_calls(label, text, acc_text, acc_items, spec):
    t = parse(text)
    if serialize(t) != text:
        raise ValueError("non-canonical tree text for " + label)
    ino, pre, post = ref_inorder(t), ref_preorder(t), ref_postorder(t)
    h, lv = ref_height(t), ref_leaves(t)
    ref = {
        "print-inorder": fmt(ino) + "\n",
        "print-all-traversals": fmt(ino) + "\n" + fmt(pre) + "\n" + fmt(post) + "\n",
        "print-height-and-leaves": fmt([str(h), str(lv)]) + "\n",
    }
    for fn in ("print-inorder", "print-all-traversals", "print-height-and-leaves"):
        exp = ref[fn]
        tag = ""
        if spec and (label, fn) in SPEC_EXPECTED:
            tag = " [spec example]"
            if SPEC_EXPECTED[(label, fn)] != exp:
                refcheck_failures.append(
                    "reference disagrees with spec for %s %s: ref=%r spec=%r"
                    % (label, fn, exp, SPEC_EXPECTED[(label, fn)]))
            exp = SPEC_EXPECTED[(label, fn)]
        emit("%s / (%s %s)%s" % (label, fn, "t", tag), fn, text, "(%s t)" % fn, exp, "small")
    emit("%s / (tree-height t)" % label, "tree-height", text,
         "(display (tree-height t))\n(newline)", str(h) + "\n", "small")
    emit("%s / (count-leaves t)" % label, "count-leaves", text,
         "(display (count-leaves t))\n(newline)", str(lv) + "\n", "small")
    for fn, order in (("inorder-onto", ino), ("preorder-onto", pre), ("postorder-onto", post)):
        emit("%s / (%s t '())" % (label, fn), fn, text,
             "(display (%s t '()))\n(newline)" % fn, fmt(order) + "\n", "small")
        emit("%s / (%s t '%s)" % (label, fn, acc_text), fn, text,
             "(display (%s t '%s))\n(newline)" % (fn, acc_text),
             fmt(order + acc_items) + "\n", "small")


for label, text in SPEC:
    all_calls(label, text, "(99)", ["99"], True)
for label, text in EDGE:
    all_calls(label, text, "(7 q 8)", ["7", "q", "8"], False)


# ---- large trees -----------------------------------------------------------
def chain(n, side):
    V = [str(i + 1) for i in range(n)]
    nxt = [i + 1 if i + 1 < n else -1 for i in range(n)]
    none = [-1] * n
    return Tree(V, nxt, none, 0) if side == "left" else Tree(V, none, nxt, 0)


def heap_shaped(n):
    V = [str(i + 1) for i in range(n)]
    L = [2 * i + 1 if 2 * i + 1 < n else -1 for i in range(n)]
    R = [2 * i + 2 if 2 * i + 2 < n else -1 for i in range(n)]
    return Tree(V, L, R, 0)


def large_case(label, t):
    text = serialize(t)
    ino, pre, post = ref_inorder(t), ref_preorder(t), ref_postorder(t)
    h, lv = ref_height(t), ref_leaves(t)
    emit("%s / (print-all-traversals t)" % label, "print-all-traversals", text,
         "(print-all-traversals t)",
         fmt(ino) + "\n" + fmt(pre) + "\n" + fmt(post) + "\n", "large")
    emit("%s / (print-height-and-leaves t)" % label, "print-height-and-leaves", text,
         "(print-height-and-leaves t)", fmt([str(h), str(lv)]) + "\n", "large")


for n in (50000, 100000, 200000):
    large_case("large left-chain %d" % n, chain(n, "left"))
    large_case("large right-chain %d" % n, chain(n, "right"))
large_case("large balanced 150000", heap_shaped(150000))

with open(os.path.join(out, "refcheck"), "w") as f:
    f.write("\n".join(refcheck_failures))
PYEOF
gen_status=$?
if [ "$gen_status" -ne 0 ]; then
  echo "FAIL reference generator crashed (exit $gen_status)"
  exit 1
fi

echo "== reference sanity"
if [ -s "$CASES/refcheck" ]; then
  while IFS= read -r line; do fail "$line"; done <"$CASES/refcheck"
else
  pass "reference implementation agrees with every spec example"
fi

# ------------------------------------------------------------------ run cases
echo "== cases"
cp "$SOL" "$WORK/base.rkt"

for d in "$CASES"/[0-9]*; do
  name=$(cat "$d/name")
  fn=$(cat "$d/fn")
  kind=$(cat "$d/kind")

  if [ "$(grep -cF "(define ($fn " "$SOL")" -eq 0 ]; then
    missing "$name (function $fn is not defined)"
    continue
  fi

  run="$WORK/run.rkt"
  cp "$WORK/base.rkt" "$run"
  printf '\n' >>"$run"
  cat "$d/tree" "$d/call" >>"$run"

  t0=$(now)
  timeout "$LIMIT" racket "$run" >"$WORK/stdout" 2>"$WORK/stderr"
  status=$?
  t1=$(now)
  secs=$(python3 -c "print('%.2f' % ($t1 - $t0))")
  timing=""
  if [ "$kind" = "large" ]; then
    timing=" (${secs}s)"
  fi

  if [ "$status" -eq 124 ]; then
    fail "$name: timed out after ${LIMIT}s"
  elif grep -qE 'unbound identifier|is not defined|undefined' "$WORK/stderr"; then
    missing "$name (undefined identifier: $(head -n 1 "$WORK/stderr"))"
  elif [ "$status" -ne 0 ]; then
    fail "$name: racket exit status $status: $(head -n 1 "$WORK/stderr" | cut -c 1-150)"
  elif [ -s "$WORK/stderr" ]; then
    fail "$name: stderr not empty: $(head -n 1 "$WORK/stderr" | cut -c 1-150)"
  elif ! cmp -s "$WORK/stdout" "$d/expected"; then
    fail "$name: stdout differs; got $(head -c 120 "$WORK/stdout" | tr '\n' '|') expected $(head -c 120 "$d/expected" | tr '\n' '|')"
  else
    pass "$name$timing"
  fi
done

echo "== summary"
echo "SUMMARY: $PASS passed, $FAIL failed, $MISSING missing, $WARN warnings"
if [ "$FAIL" -eq 0 ] && [ "$MISSING" -eq 0 ]; then
  exit 0
fi
exit 1
