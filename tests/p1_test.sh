:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).

% Tests for code/q1.pl (P1, Department Assignment Puzzle).
% Run (absolute paths, exit status 0 = all passed):
%   swipl -q -g "consult('/abs/code/q1.pl'), consult('/abs/tests/q1_tests.pl'), t_all" -t halt
% Every expected value comes from the independent oracle below (o_*), which
% never calls candidate/1 or clue/2 from code/q1.pl.

% ---------------------------------------------------------------------------
% Oracle
% ---------------------------------------------------------------------------

% o_depts(-Ds), o_langs(-Ls), o_projects(-Ps): the value sets from the spec.
o_depts([research, development, design, testing]).
o_langs([python, java, 'c++', javascript]).
o_projects(['AI', web, embedded, data]).

% o_perm(+List, -Perm): Perm is a permutation of List (own enumerator).
o_perm([], []).
o_perm(List, [X|Xs]) :-
    select(X, List, Rest),
    o_perm(Rest, Xs).

% o_candidate(?S): S is a filled-in list for Alex, Ben, Carla, Dana in that
% order, with each attribute's four values used exactly once.
o_candidate([p('Alex', D1, L1, P1), p('Ben', D2, L2, P2),
             p('Carla', D3, L3, P3), p('Dana', D4, L4, P4)]) :-
    o_depts(Ds), o_perm(Ds, [D1, D2, D3, D4]),
    o_langs(Ls), o_perm(Ls, [L1, L2, L3, L4]),
    o_projects(Ps), o_perm(Ps, [P1, P2, P3, P4]).

% o_all(-Cs): Cs is the list of all oracle candidates.
o_all(Cs) :-
    findall(S, o_candidate(S), Cs).

% o_clue(+N, +S): clue N of the spec holds in the candidate S; each clue is
% written as "no friend in S breaks it".
% 1. The friend who prefers the AI project does not work in research and is not Dana.
o_clue(1, S) :-
    \+ ( member(p(N, D, _, P), S), P == 'AI', ( D == research ; N == 'Dana' ) ).
% 2. Alex does not work in development and does not prefer C++.
o_clue(2, S) :-
    \+ ( member(p(N, D, L, _), S), N == 'Alex', ( D == development ; L == 'c++' ) ).
% 3. The friend working in the testing department likes Python.
o_clue(3, S) :-
    \+ ( member(p(_, D, L, _), S), D == testing, L \== python ).
% 4. Ben prefers web projects and does not work in testing.
o_clue(4, S) :-
    \+ ( member(p(N, D, _, P), S), N == 'Ben', ( P \== web ; D == testing ) ).
% 5. The friend whose favorite language is Java works in the design department.
o_clue(5, S) :-
    \+ ( member(p(_, D, L, _), S), L == java, D \== design ).
% 6. Carla's project preference is not embedded, and her department is not development.
o_clue(6, S) :-
    \+ ( member(p(N, D, _, P), S), N == 'Carla', ( P == embedded ; D == development ) ).
% 7. Dana's favorite language is not Java, and she works in research or testing.
o_clue(7, S) :-
    \+ ( member(p(N, D, L, _), S), N == 'Dana',
         ( L == java ; ( D \== research, D \== testing ) ) ).
% 8. The friend who prefers data projects works in research and does not use JavaScript.
o_clue(8, S) :-
    \+ ( member(p(_, D, L, P), S), P == data, ( D \== research ; L == javascript ) ).
% 9. The friend who prefers the AI project likes Python.  (from the % CLUE 9: line)
o_clue(9, S) :-
    \+ ( member(p(_, _, L, P), S), P == 'AI', L \== python ).

% o_clue9_sentence(-Line): the clue 9 comment line the oracle's clue 9 encodes.
o_clue9_sentence("% CLUE 9: The friend who prefers the AI project likes Python.").

% o_holds(+Active, +S): every clue numbered in Active holds in S by the oracle.
o_holds(Active, S) :-
    \+ ( member(K, Active), \+ o_clue(K, S) ).

% o_solutions(+Active, -Sols): Sols is the sorted list of oracle candidates in
% which every clue in Active holds.
o_solutions(Active, Sols) :-
    findall(S, (o_candidate(S), o_holds(Active, S)), Sols0),
    sort(Sols0, Sols).

% o_render(+S, -Text): Text is the spec's printed form of S, built without format/2.
o_render(S, Text) :-
    findall(Line,
            ( member(p(N, D, L, P), S),
              atomic_list_concat([N, ' = [', D, ', ', L, ', ', P, ']\n'], Line) ),
            Lines),
    atomic_list_concat(Lines, A),
    atom_string(A, Text).

% o_iff(+G1, +G2): G1 succeeds exactly when G2 succeeds.
o_iff(G1, G2) :-
    (   \+ \+ call(G1)
    ->  \+ \+ call(G2)
    ;   \+ call(G2)
    ).

% o_count(+G, -C): C is the number of successes of G.
o_count(G, C) :-
    aggregate_all(count, G, C).

% ---------------------------------------------------------------------------
% Hand-built ground examples (validity and expected clue results come from the oracle)
% ---------------------------------------------------------------------------

% o_invalid(-Label, -S): S is a ground list that is not a candidate.
o_invalid(repeated_dept,
    [p('Alex', research, python, 'AI'), p('Ben', research, java, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, data)]).
o_invalid(wrong_name_order,
    [p('Ben', research, python, 'AI'), p('Alex', development, java, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, data)]).
o_invalid(three_friends,
    [p('Alex', research, python, 'AI'), p('Ben', development, java, web),
     p('Carla', design, 'c++', embedded)]).
o_invalid(unknown_value,
    [p('Alex', research, python, 'AI'), p('Ben', development, java, web),
     p('Carla', design, rust, embedded), p('Dana', testing, javascript, data)]).

% o_violation(-N, -Condition, -S): S is a candidate built to break the named
% condition of clue N.
o_violation(1, ai_in_research,
    [p('Alex', research, python, 'AI'), p('Ben', development, java, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, data)]).
o_violation(1, ai_is_dana,
    [p('Alex', research, python, data), p('Ben', development, java, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, 'AI')]).
o_violation(2, alex_development,
    [p('Alex', development, python, 'AI'), p('Ben', research, java, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, data)]).
o_violation(2, alex_cpp,
    [p('Alex', research, 'c++', 'AI'), p('Ben', development, java, web),
     p('Carla', design, python, embedded), p('Dana', testing, javascript, data)]).
o_violation(3, testing_not_python,
    [p('Alex', testing, java, 'AI'), p('Ben', development, python, web),
     p('Carla', design, 'c++', embedded), p('Dana', research, javascript, data)]).
o_violation(4, ben_not_web,
    [p('Alex', research, python, web), p('Ben', development, java, 'AI'),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, data)]).
o_violation(4, ben_testing,
    [p('Alex', research, python, 'AI'), p('Ben', testing, java, web),
     p('Carla', design, 'c++', embedded), p('Dana', development, javascript, data)]).
o_violation(5, java_not_design,
    [p('Alex', research, java, 'AI'), p('Ben', development, python, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, data)]).
o_violation(6, carla_embedded,
    [p('Alex', research, python, 'AI'), p('Ben', development, java, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, data)]).
o_violation(6, carla_development,
    [p('Alex', research, python, 'AI'), p('Ben', design, java, web),
     p('Carla', development, 'c++', data), p('Dana', testing, javascript, embedded)]).
o_violation(7, dana_java,
    [p('Alex', research, python, 'AI'), p('Ben', development, javascript, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, java, data)]).
o_violation(7, dana_not_research_or_testing,
    [p('Alex', research, python, 'AI'), p('Ben', development, java, web),
     p('Carla', testing, 'c++', embedded), p('Dana', design, javascript, data)]).
o_violation(8, data_not_research,
    [p('Alex', research, python, 'AI'), p('Ben', development, java, data),
     p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, web)]).
o_violation(8, data_javascript,
    [p('Alex', research, javascript, data), p('Ben', development, java, web),
     p('Carla', design, 'c++', embedded), p('Dana', testing, python, 'AI')]).

% o_layout_input(-S), o_layout_text(-T): the spec's layout example and its
% four lines, copied from the spec (a layout test, not an answer).
o_layout_input([p('Alex', research, python, 'AI'), p('Ben', development, java, web),
                p('Carla', design, 'c++', embedded), p('Dana', testing, javascript, data)]).
o_layout_text("Alex = [research, python, AI]\nBen = [development, java, web]\nCarla = [design, c++, embedded]\nDana = [testing, javascript, data]\n").

% o_other_input(-S): another candidate for the print test.
o_other_input([p('Alex', design, java, embedded), p('Ben', development, javascript, web),
               p('Carla', testing, python, 'AI'), p('Dana', research, 'c++', data)]).

% o_active_lists(-Ls): clue lists used by the solution/2 and count tests.
o_active_lists([[], [1, 2, 3, 4, 5, 6, 7, 8], [1, 2, 3, 4, 5, 6, 7, 8, 9],
                [8, 7, 6, 5, 4, 3, 2, 1], [3, 3, 1], [1, 3], [2, 4, 6], [9], [99]]).

% ---------------------------------------------------------------------------
% Tests
% ---------------------------------------------------------------------------

% t_candidate: candidate/1 gives exactly the oracle's candidates, once each,
% and rejects invalid ground lists.
t_candidate :-
    findall(S, candidate(S), L),
    o_all(O),
    length(O, NO),
    length(L, NO),
    sort(L, U), length(U, NO),
    sort(O, OS), U == OS,
    o_layout_input(V), o_candidate(V),
    o_count(candidate(V), 1),
    forall(o_invalid(_, X), ( \+ o_candidate(X), \+ candidate(X) )).

% t_clues: clue(N, S) agrees with the oracle on every candidate for N = 1..9,
% succeeds at most once, fails on each hand-built violation, and clue 9 meets
% the P1.c requirements.
t_clues :-
    o_all(Cs),
    forall(between(1, 9, N),
           forall(member(S, Cs),
                  ( o_count(clue(N, S), C),
                    ( o_clue(N, S) -> C =:= 1 ; C =:= 0 ) ))),
    forall(o_violation(N, _, S),
           ( o_candidate(S), \+ o_clue(N, S), \+ clue(N, S) )),
    t_clue9_unique,
    t_clue9_text.

% t_clue9_unique: by the oracle, clue 9 is true in exactly one solution of clues 1..8.
t_clue9_unique :-
    o_solutions([1, 2, 3, 4, 5, 6, 7, 8], S8),
    o_count(( member(S, S8), o_clue(9, S) ), 1).

% t_clue9_text: in the loaded source, the line directly above the clue(9, ...)
% clause is the % CLUE 9: line the oracle encodes, and neither it nor the
% clause mentions a friend by name.
t_clue9_text :-
    source_file(clue(_, _), File),
    setup_call_cleanup(open(File, read, In), read_string(In, _, Text), close(In)),
    split_string(Text, "\n", "", Lines),
    findall(I, ( nth1(I, Lines, L), sub_string(L, 0, _, _, "clue(9,") ), [I]),
    I0 is I - 1,
    nth1(I0, Lines, Above),
    sub_string(Above, 0, _, _, "% CLUE 9:"),
    o_clue9_sentence(Above),
    length(Before, I0), append(Before, From, Lines),
    o_clause_lines(From, ClauseLines),
    forall(member(T, [Above|ClauseLines]), \+ o_mentions_name(T)).

% o_clause_lines(+Lines, -Clause): Clause is the prefix of Lines up to and
% including the first line ending in a full stop (the cut stops at that line).
o_clause_lines([L|_], [L]) :-
    split_string(L, "", " \t", [T]),
    sub_string(T, _, 1, 0, "."), !.
o_clause_lines([L|Ls], [L|Cs]) :-
    o_clause_lines(Ls, Cs).

% o_mentions_name(+Text): Text contains one of the friends' names.
o_mentions_name(Text) :-
    member(Name, ["Alex", "Ben", "Carla", "Dana"]),
    sub_string(Text, _, _, _, Name).

% t_clues_hold: clues_hold/2 against clue/2 and the oracle on every candidate.
t_clues_hold :-
    o_all(Cs),
    forall(member(S, Cs),
           ( clues_hold([], S),
             forall(between(1, 9, K), o_iff(clues_hold([K], S), clue(K, S))),
             o_iff(clues_hold([1, 2, 3, 4, 5, 6, 7, 8], S),
                   o_holds([1, 2, 3, 4, 5, 6, 7, 8], S)),
             o_count(clues_hold([1, 2, 3, 4, 5, 6, 7, 8], S), C), C =< 1,
             \+ clues_hold([99], S),
             o_iff(clues_hold([3, 3, 1], S), clues_hold([1, 3], S)),
             o_iff(clues_hold([8, 7, 6, 5, 4, 3, 2, 1], S),
                   clues_hold([1, 2, 3, 4, 5, 6, 7, 8], S)) )).

% t_solution: for each test list, solution/2's answers are the oracle's, with
% no duplicates.
t_solution :-
    o_active_lists(As),
    forall(member(A, As),
           ( findall(S, solution(A, S), L),
             length(L, N), sort(L, U), length(U, N),
             o_solutions(A, O), U == O )).

% t_print_solution: exact printed text, including the final newline, for the
% spec layout input and one other candidate; succeeds exactly once.
t_print_solution :-
    o_layout_input(S1), o_layout_text(T1),
    o_render(S1, T1),
    with_output_to(string(P1), print_solution(S1)), P1 == T1,
    o_other_input(S2), o_candidate(S2), o_render(S2, T2),
    with_output_to(string(P2), print_solution(S2)), P2 == T2,
    with_output_to(string(P3), findall(x, print_solution(S1), Xs)),
    length(Xs, 1), P3 == T1.

% t_main: main prints four lines of the required shape, names in order, equal
% to the printed form of one oracle solution of clues 1..8, and succeeds once.
% with_output_to/2 runs its goal as once/1, so the findall goes inside it to
% count main's successes and capture everything all of them print.
t_main :-
    with_output_to(string(Out), findall(x, main, Xs)),
    length(Xs, 1),
    split_string(Out, "\n", "", Parts),
    append(Lines, [""], Parts),
    length(Lines, 4),
    maplist(o_line_shape, ['Alex', 'Ben', 'Carla', 'Dana'], Lines),
    o_solutions([1, 2, 3, 4, 5, 6, 7, 8], Sols),
    member(S, Sols), o_render(S, Out), !.

% o_line_shape(+Name, +Line): Line is "Name = [V1, V2, V3]" with three
% non-empty unquoted values separated by a comma and one space.
o_line_shape(Name, Line) :-
    atom_string(Name, NS),
    string_concat(NS, " = [", Pre),
    string_concat(Pre, Rest, Line),
    string_concat(Mid, "]", Rest),
    atom_string(MidA, Mid),
    atomic_list_concat(Vals, ', ', MidA),
    length(Vals, 3),
    forall(member(V, Vals),
           ( V \== '', \+ sub_atom(V, _, _, _, ' '), \+ sub_atom(V, _, _, _, '''') )).

% t_count_solutions: count_solutions/2 gives the oracle's integer count, once,
% for every test list and every single clue; [] gives 13824 and [1..9] gives 1.
t_count_solutions :-
    o_active_lists(As),
    findall([K], between(1, 9, K), Singles),
    append(As, Singles, All),
    forall(member(A, All),
           ( findall(N, count_solutions(A, N), [N]),
             integer(N),
             o_solutions(A, O), length(O, N) )),
    count_solutions([], N0), N0 =:= 13824,
    count_solutions([1, 2, 3, 4, 5, 6, 7, 8, 9], N9), N9 =:= 1,
    count_solutions([99], N99), N99 =:= 0,
    count_solutions([3, 3, 1], NA), count_solutions([1, 3], NB), NA =:= NB.

% ---------------------------------------------------------------------------
% Runner
% ---------------------------------------------------------------------------

% o_tests(-Ts): each test with the predicates of code/q1.pl it needs.
o_tests([t_candidate-[candidate/1],
         t_clues-[clue/2],
         t_clues_hold-[clues_hold/2, clue/2],
         t_solution-[solution/2],
         t_print_solution-[print_solution/1],
         t_main-[main/0],
         t_count_solutions-[count_solutions/2]]).

% t_all: every test passes; prints one line per failing test and nothing otherwise.
t_all :-
    o_tests(Ts),
    findall(T, ( member(T-Ps, Ts), \+ o_run(T, Ps) ), Failed),
    Failed == [].

% o_run(+T, +Preds): test T passes; otherwise one line naming it is printed.
% If-then-else picks exactly one report per test.
o_run(T, Ps) :-
    (   member(P, Ps), \+ current_predicate(P)
    ->  format("MISSING ~w (~w)~n", [P, T]), fail
    ;   catch(T, E, true)
    ->  (   var(E)
        ->  true
        ;   format("FAIL ~w: error ~q~n", [T, E]), fail
        )
    ;   format("FAIL ~w~n", [T]), fail
    ).
