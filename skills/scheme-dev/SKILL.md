---
name: scheme-dev
description: Use when writing, reviewing or testing Racket code in #lang racket/base under a restricted built-in allowlist (PPL assignment .rkt files graded by appending calls to the file). Covers the allowlist, silent loading, output format, test commands and a pre-reply checklist.
---

# scheme-dev

## Language and version
- Grading uses Racket 8.x; local Racket may be newer (9.x). Line 1 is exactly `#lang racket/base`.
- Stay inside the allowlist below. That also keeps the code 8.x-safe, since nothing outside it is used.
- 8.x compatibility is inferred, not tested; do not claim it was verified.

## Coding conventions
- Names: lowercase with hyphens (`count-leaves`); helpers get descriptive names (`my-reverse`, `walk-left`).
- A binder (parameter, `let` variable) must never share a name with a forbidden builtin or a core form (`case`, `if`, `list`...).
- Every top-level form is a `define`. No top-level expressions, demos or `display`.
- Define each required function exactly once. Do not leave an old version beside a new one.
- Add each new unit at the end of the file, before nothing else. Never reorder, rewrite or delete existing units unless the prompt says so. Function definitions may refer to functions defined later in the file, so order does not matter for correctness.
- Above EVERY function write a comment with its recursive reading:
  `;; (name arg ...): base case: <...>; otherwise: <how the answer is built from the answers for the smaller parts>`
- Pass all state through arguments. Use accumulators and tail calls where natural; do not use repeated appends in a loop.
- Tell atoms from lists only with `pair?` and `null?`. `()` is a list, not an atom, at every depth.
- One unit per prompt and per commit: one function, one test file or one review.
- The last expression of every printing function must return void (normally `(newline)`). In a module, the grader's appended call `(print-x t)` prints any non-void result after the function's own output, so a function that ends in a value, a list or a number produces extra text.
- Write the empty list as `'()` in code. A bare `()` is a syntax error (missing procedure expression). Every `cond` ends with an `else` clause.

## Rules of this assignment
Copied from the assignment PDF:
- Environment: Racket 8.x. "Scheme code is written in #lang racket/base and uses nothing but the built-ins listed for each problem." File names: id_q3.rkt, id_q4.rkt.
- "Only the following built-ins may be used: define, lambda, let, let*, letrec, named let, if, cond (with else), and, or, not, begin, quote (written '), cons, car, cdr, list, every composition of car and cdr up to four levels (cadr, cddr, caddr, cdddr, cadddr, cddddr, and so on), null?, pair?, eq?, assq, assoc, the arithmetic and comparison operators + - * < > <= >= =, max, display and newline. S2 additionally allows read."
- "Nothing else from racket/base may be used. In particular: no set! or its relatives, no vectors, hash tables or strings, no loops (do, for), and no length, append, reverse, map, filter, member, memq, list-ref or list-tail. If you need such a function, write your own helper (for example my-reverse)."
- How it is run: `racket id_q3.rkt` and `racket id_q4.rkt`; "the grader adds its own calls to the end of your file".
- "Racket files start with #lang racket/base. Do not call your functions at the top level and do not print anything when the file is loaded."
- Consequences of the list above (not PDF text): anything not on it is forbidden, e.g. `list?`, `symbol?`, `number?`, `equal?`, `eqv?`, `abs`, `min`, `zero?`, `error`, `void`, string literals, `#\` characters, `#:` keywords. Compare numbers with `=`, symbols with `eq?`.
- Output uses `display` (never `write`). Each printing function ends its output with `newline`.
- Hidden tests use large inputs (deep nesting, long lists). Keep running time linear: no repeated appends, no recomputing a subresult twice.

## How to run and test
- Load check, must print nothing: `[ -z "$(racket FILE 2>&1)" ] && echo SILENT` (anything else means output or an error).
- Call one function: `cp FILE /tmp/t.rkt; echo "(fn arg)" >> /tmp/t.rkt; racket /tmp/t.rkt`.
- Stdin function: `printf '...' | racket /tmp/t.rkt`. Also test with no trailing newline and with extra whitespace or newlines.
- Compare stdout exactly (`diff` against an expected file made by a reference implementation). Each call's output ends in `\n`.
- Per unit, where it applies: test the empty input, `()` at several depths, one element, and the largest sizes the spec mentions (and beyond).
- Timing: run n, 2n and 4n inputs; the time should roughly double each step.
- Count definitions: `grep -c '(define (NAME ' FILE` is 1 for each required name. Append a call to each required function and run.

## When writing tests (test harnesses and linters, not the solution file)
- An allowlist linter must flag every symbol that is neither allowlisted nor locally bound. Collecting binders for the whole file lets a parameter named like a forbidden builtin whitelist that name, and char literals and keywords slip through. Do not trust the linter blindly: also grep for `#\`, `#:`, and forbidden names.
- In full-Racket tooling, do not name a struct or helper after a core form (`case`). It causes a confusing `unbound identifier` error later. Read the location the error points to.
- Generate expected outputs with an independent reference implementation, never by mental arithmetic. Run the reference on every hand-picked input first.
- Where several outputs are valid, the test must accept all of them.
- Mutation-check the tests (flip a comparison, drop a base case, drop a newline). Each mutant must fail some test.
- Stdin writers must ignore write errors (broken pipe when the program exits early). Use exit statuses, exact diffs and absolute paths. Report undefined functions as MISSING, not as a crash.

## Self-review checklist (answer yes or no before replying)
1. Is line 1 exactly `#lang racket/base`, and is every top-level form a `define`?
2. Does `racket FILE` alone print nothing?
3. Does the last expression of every printing function return void (normally `(newline)`), and is the empty list written `'()`, with every `cond` ending in `else`?
4. Does every symbol used appear on the allowlist, or is it your own definition or local binding?
5. Does any binder share a name with a forbidden builtin or a core form? (It must not.)
6. Is each required function defined exactly once, and is every helper it calls defined?
7. Does every printing function use `display` and end with `newline`?
8. Are atoms and lists told apart only with `pair?`/`null?`, with `()` handled as a list?
9. Is the code free of `list?`, `symbol?`, `number?`, string literals, `#\`, `#:`, `set!` and loops?
10. Are there no appends inside loops, and does the time double when the input doubles?
11. Does it run on the largest and deepest inputs the spec mentions without errors?
12. Are sequential `read`s ordered with `let*`, and do they tolerate any whitespace?
13. Does every function have a comment with its recursive reading?
14. Does the code give the correct result for every example in the prompt, and did you state any assumption you made about an ambiguous point?

## Known failure modes of AI tools for Scheme
- Using forbidden builtins out of habit (`append`, `length`, `map`, `filter`, `reverse`, `member`, `list?`, `for`, `set!`, strings, `error`, `void`).
- Leaving demo calls or `display` at the top level, or a wrong `#lang` line.
- `write` instead of `display`, a missing final `newline`, an extra space.
- Defining a name twice, or calling a helper that was never defined; one compile error fails every appended grader call.
- Using `pair?` alone, so `()` is treated as an atom; using non-allowlisted type predicates.
- Quadratic running time (repeated appends, recomputing a subresult) that is too slow on long or deeply nested inputs.
- Several `read`s in one `let`, relying on an evaluation order. Use `let*` so the order is explicit.
- Binders named like builtins or core forms.
- Hand-computed expected outputs, unchecked test inputs, silently chosen spec readings.
- A printing function whose last expression is not void, so the appended grader call prints a stray value.
- A bare `()` in code instead of `'()`, or a `cond` without `else`.
