# P1 Report: Department Assignment Puzzle

## Value of N (P1.b)

```
?- count_solutions([1,2,3,4,5,6,7,8], N).
N = 3.
```

**N = 3**: exactly three of the 13824 candidate assignments satisfy clues 1 to 8.

## What it tells us about the puzzle

The eight clues are consistent (N > 0) but do not determine a unique answer (N > 1).
The puzzle as given is under-constrained, so some extra information is needed to pin down one answer.

The three solutions of clues 1 to 8 are:

| | Solution 1 | Solution 2 | Solution 3 |
|---|---|---|---|
| Alex  | design, java, AI           | design, java, embedded     | testing, python, embedded |
| Ben   | development, javascript, web | development, javascript, web | development, javascript, web |
| Carla | research, c++, data        | testing, python, AI        | design, java, AI          |
| Dana  | testing, python, embedded  | research, c++, data        | research, c++, data       |

- Ben's row is the same in all three, so clues 1 to 8 fix Ben completely (development, javascript, web).
- Solutions 1 and 3 contain the same four (department, language, project) combinations:
  design/java/AI, development/javascript/web, research/c++/data and testing/python/embedded.
  They differ only in which friend holds which combination.
  A clue that refers to friends only through attribute values, as P1.c requires, therefore cannot tell
  Solution 1 from Solution 3. Solution 2 is the only one that such a clue can single out.
- `main/0` prints the first solution found, Solution 1. The spec asks for any one solution of clues 1 to 8.

## Repair (P1.c)

The added clue keeps Solution 2:

```prolog
% CLUE 9: The friend who prefers the AI project likes Python.
```

In Solution 2 the AI friend (Carla) likes Python. In Solutions 1 and 3 the AI friend likes Java, so clue 9 fails there.
With the ninth clue the answer is unique:

```
?- count_solutions([1,2,3,4,5,6,7,8,9], N).
N = 1.
```

## How to reproduce

```
swipl -q -f code/q1.pl -g "count_solutions([1,2,3,4,5,6,7,8],N), writeln(N)" -t halt
swipl -q -f code/q1.pl -g "forall(solution([1,2,3,4,5,6,7,8],S), (print_solution(S), nl))" -t halt
swipl -q -f code/q1.pl -g "count_solutions([1,2,3,4,5,6,7,8,9],N), writeln(N)" -t halt
```
