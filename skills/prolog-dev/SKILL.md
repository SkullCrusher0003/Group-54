---
name: prolog-dev
description: Use when writing, reviewing or testing SWI-Prolog code (.pl files) for the PPL assignment or any task graded by running swipl with -g goals. Covers allowed libraries, load-time silence, output format, test commands and a pre-reply checklist.
---

# prolog-dev

## Language and version
- Grading uses SWI-Prolog 9.x. Local swipl may be newer (11.x); do not assume it matches.
- Use only long-established features: plain clauses, lists/apply/yall/aggregate predicates, `format/2`, `findall/3`, `forall/2`, `msort/2`, `sort/2`.
- Avoid dicts, new flags, new library predicates and new `format` directives.
- 9.x compatibility is inferred, not tested; do not claim it was verified.

## Coding conventions
- Predicate and variable names: snake_case atoms, CamelCase variables. No singleton variables (use `_` or `_Name` on purpose).
- Keep all clauses of one predicate together (contiguous).
- Add each new unit at the end of the file. Never reorder, rewrite or delete existing units unless the prompt says so. A tiny helper used only by the new predicate goes right after it.
- Above EVERY predicate write a comment with its mode line and a declarative reading:
  `% name(+In, -Out): <true when ... / Out is ... such that ...>`
  The reading says what holds, not what steps run.
- Pure logic first: prefer unification and relations over if-then-else and cuts. If a cut or `->` is used, say why in a comment.
- One unit per prompt and per commit: one predicate, one test file or one review.
- Compute values from terms, never from printed text. Do not build text and parse it back (`term_to_atom`, `term_string`, `read_term_from_atom`).
- Atoms that start with a capital letter or contain symbols must be quoted in source (`'Hello'`, `'a+b'`). `~w` prints them unquoted; `~q`, `print` and `writeq` print the quotes. Use whichever the spec's output format needs.
- Files hold definitions only. The only directives allowed are `:- use_module(library(...))` for allowed libraries.

## Rules of this assignment
Copied from the assignment PDF:
- Environment: SWI-Prolog 9.x. File names: id_q1.pl, id_q2.pl (id = group ID).
- "How your code is run: Prolog: swipl -q -f id_q1.pl -g main -t halt (runs main), and for other predicates swipl -q -f id_q1.pl -g "<goal>" -t halt. Do not call halt/0 yourself and do not use any initialization directive."
- "Prolog files must not contain any initialization directive."
- "What your files contain: only definitions." Nothing may be printed when the file is loaded.
- P1: "no assert, retract or global variables (b_setval, nb_setval). Allowed libraries: lists, apply, yall, aggregate. Do not print anything other than what is specified."
- P2: "no assert, retract or global variables. Do not build a string and parse it back into a term to evaluate it. Allowed libraries: lists, apply, yall, aggregate. Do not print anything."
- When a spec says an SWI-Prolog string, return a string (not an atom, not a code list).
- When a spec says a predicate must fail, it must fail: no error, no loop.
- Library check: every non-built-in predicate you call must come from lists, apply, yall or aggregate. SWI autoloads other libraries (pairs, ordsets, solution_sequences, option, strings, dcg/basics...) with no `use_module`, so a call that works is not necessarily allowed.

## How to run and test
- Load check, must print nothing: `[ -z "$(swipl -q -f FILE -g true -t halt 2>&1)" ] && echo SILENT` (anything else means output or warnings).
- Run main: `swipl -q -f FILE -g main -t halt`
- Run one goal: `swipl -q -f FILE -g "Goal" -t halt; echo $?`
- Unit test: one test predicate per unit in tests/, loaded by absolute path:
  `swipl -q -g "consult('/abs/code/f.pl'), consult('/abs/tests/t.pl'), t_unit" -t halt; echo $?`
- A test checks: the result, its type (`string/1` etc.), the exact printed text via `with_output_to(string(S), G)` including `\n`, the solution count via `findall`, and clean failure.

## When writing tests (test harnesses, not the solution file)
- Lambda `>>` and `:` are both 200 xfy. Write `[X]>>(m:g(X))`, with parentheses. Grep for `>>[a-z_]*:`.
- yall copies a lambda before calling it, so a variable still unbound outside is not bound by the lambda. Share variables explicitly with `Free/[X]>>Goal`. Test the loaded file, since behaviour can differ between compiled and dynamic use.
- To search a term that has variables for a bound term, use `sub_term(X, T), X == Atom`. `\+ sub_term(Atom, T)` unifies with variables and gives wrong answers.
- `swipl ... script.pl arg` loads `arg` as another file. Use `--`, and print `current_prolog_flag(argv, A)` once to confirm.
- Load files by absolute path (`absolute_file_name/3`). Relative loads warn on 11.x.
- Never parse plunit output (its format differs between versions and it buffers). Use `run_tests(Unit:Test)` and the exit status only.
- Make expected values with an independent brute-force oracle, not mental arithmetic. Run the oracle on every hand-picked input, including "no answer" ones.
- Where the spec accepts any valid answer, the test must accept every valid answer.
- Mutation-check the tests: flip a comparison, drop a condition, drop a newline, drop a sort. Each mutant must fail some test.
- Make test runners use exit statuses, exact stdout diffs and absolute paths. Report an undefined predicate as MISSING.

## Self-review checklist (answer yes or no before replying)
1. Does `swipl -q -f FILE -g true -t halt` print nothing on stdout and stderr?
2. Is the file free of `initialization`, `halt`, assert/retract, global variables, and directives other than allowed `use_module`?
3. Does every non-built-in predicate used come from lists, apply, yall or aggregate (no silently autoloaded library)?
4. Does each printed line match the format exactly (`~w` vs `~q`, spaces, trailing `\n`)?
5. Is every returned value of the required type, checked with a type test?
6. Do predicates meant to succeed once succeed exactly once (no inflated `findall` counts)?
7. Is "every element satisfies G" written with `forall/2` and not `member/2`?
8. Do `[]`, one-element input and no-answer input fail cleanly, with no error and no loop?
9. Are clauses of each predicate contiguous, with no singleton variables?
10. Is every predicate commented with a mode line and declarative reading?
11. Does nothing build text and parse it back to compute a value?
12. Are only long-established SWI 9.x features used?
13. Does the code give the correct result for every example in the prompt, and did you state any assumption you made about an ambiguous point?
14. Are atoms needing quotes quoted in source, and does printing use `~w` or `~q` as the spec requires?

## Known failure modes of AI tools for Prolog
- Operator precedence surprises in `yall` lambdas with `:`.
- Using unification-based search (`member`, `sub_term`) where `==` is needed.
- Load-time warnings (singletons after deleting a condition, discontiguous clauses) counted as output.
- Reaching for forbidden constructs by habit: assert/retract, global variables, `initialization`, `halt`, extra libraries.
- Wrong text type (atom vs string vs codes) or `~q` vs `~w`; missing or extra whitespace.
- Multi-success goals that inflate counts.
- Non-termination on `[]`, singletons or empty partitions.
- Evaluating by printing and parsing text.
- Newer-than-9.x behaviour assumed from the local version.
- Hand-computed expected outputs, unchecked test inputs, silently chosen spec readings.
- Calling predicates from non-allowed libraries that autoload silently (pairs, ordsets, solution_sequences...).
- yall lambdas that fail to bind outer variables because free variables were not declared with `/`.
- `msort/2` where `sort/2` is needed (`sort/2` removes duplicates, `msort/2` keeps them), or the reverse.