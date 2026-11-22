:- use_module(library(lists)).

% Tests for expr_tree/3, valid_equation/2, generate_equation/2,
% all_equations/2 and count_equations/2 of code/q2.pl (P2, Form a Valid
% Arithmetic Equation).
% Run (absolute paths, exit status 0 = every test passed):
%   swipl -q -g "consult('/abs/code/q2.pl'), consult('/abs/tests/q2_enum_test.pl'), t_q2_enum" -t halt
% The runner prints one line per test: PASS name / FAIL name: reason / MISSING name.
% Expected values come from the spec or from the brute-force oracle below
% (q_*), which is written from the spec text and calls nothing from
% code/q2.pl. Trees: n(V) and e(Op, L, R).

% ---------------------------------------------------------------------------
% Oracle (independent of code/q2.pl)
% ---------------------------------------------------------------------------

% q_ops(-Ops): the four operators.
q_ops(['+', '-', '*', '/']).

% q_rank(+Op, -Rank): binding strength, * and / tighter than + and -.
q_rank('+', 1).
q_rank('-', 1).
q_rank('*', 2).
q_rank('/', 2).

% q_apply(+Op, +A, +B, -V): V is "A Op B"; division only when B is not zero and
% A has remainder 0 when divided by B (checked with rem/2, not mod/2).
q_apply('+', A, B, V) :- V is A + B.
q_apply('-', A, B, V) :- V is A - B.
q_apply('*', A, B, V) :- V is A * B.
q_apply('/', A, B, V) :- B =\= 0, 0 =:= A rem B, V is A div B.

% q_split(+List, -Left, -Right): Left and Right are non-empty and Left followed
% by Right is List.
q_split(List, Left, Right) :-
    length(List, K),
    K1 is K - 1,
    between(1, K1, J),
    length(Left, J),
    append(Left, Right, List).

% q_trees(+List, -Pairs): Pairs is the list of all Tree-Value pairs over the
% numbers of List in order (every split, every operator, valid divisions only).
q_trees([], []).
q_trees([N], [n(N)-N]).
q_trees(List, Pairs) :-
    List = [_, _|_],
    findall(e(Op, TL, TR)-V,
            ( q_split(List, L, R),
              q_trees(L, Ls),
              q_trees(R, Rs),
              member(TL-VL, Ls),
              member(TR-VR, Rs),
              q_ops(Ops),
              member(Op, Ops),
              q_apply(Op, VL, VR, V) ),
            Pairs).

% q_codes(+Tree, -Codes): the canonical text of Tree as a code list; an operand
% is wrapped in parentheses when it is an operation whose rank is lower than the
% parent's (left operand) or lower than or equal to it (right operand).
q_codes(n(V), Codes) :-
    number_codes(V, Codes).
q_codes(e(Op, L, R), Codes) :-
    q_rank(Op, P),
    q_operand(left, P, L, LC),
    q_operand(right, P, R, RC),
    atom_codes(Op, OC),
    append([LC, OC, RC], Codes).

% q_operand(+Side, +ParentRank, +Tree, -Codes): operand text, wrapped when the
% spec says so.
q_operand(Side, P, Tree, Codes) :-
    q_codes(Tree, C0),
    (   Tree = e(Op, _, _),
        q_rank(Op, Q),
        q_wrapped(Side, Q, P)
    ->  append([[0'(], C0, [0')]], Codes)
    ;   Codes = C0
    ).

% q_wrapped(+Side, +ChildRank, +ParentRank): the child needs parentheses.
q_wrapped(left, Q, P) :- Q < P.
q_wrapped(right, Q, P) :- Q =< P.

% q_raw(+List, -All): All is the list of equation strings of List, one for each
% (split, left tree, right tree) with equal values, in generation order.
q_raw(List, All) :-
    findall(S,
            ( q_split(List, L, R),
              q_trees(L, Ls),
              q_trees(R, Rs),
              member(TL-V, Ls),
              member(TR-V, Rs),
              q_codes(TL, CL),
              q_codes(TR, CR),
              append([CL, [0'=], CR], Codes),
              string_codes(S, Codes) ),
            All).

% q_equations(+List, -Sorted): the equations of List, sorted with sort/2.
q_equations(List, Sorted) :-
    q_raw(List, All),
    sort(All, Sorted).

% ---------------------------------------------------------------------------
% Test data and helpers
% ---------------------------------------------------------------------------

% e_seven(-Es): the seven equations of [4,2,5,3] in the order of the spec.
e_seven(["4*2-5=3", "4*2=5+3", "4-2=5-3", "4/2=5-3",
         "4=2*(5-3)", "4=2+(5-3)", "4=2+5-3"]).

% e_battery(-Lists): the tricky lists of e_case/1.
e_battery(Lists) :-
    findall(L, e_case(L), Lists).

% e_case(?List): tricky lists: remainders inside larger expressions (1/2*4
% style), division by zero, negative intermediate values, zeros, repeated
% numbers, multi-digit numbers.
e_case([1,2,4,2]).
e_case([5,0,0]).
e_case([3,5,1,3]).
e_case([3,5,2,0]).
e_case([12,3,4]).
e_case([2,2,2,2]).
e_case([0,0,0]).
e_case([1,1,1,1,1]).
e_case([6,3,2,1,1]).
e_case([4,2,5,3]).
e_case([2,4,8]).
e_case([10,5,2]).
e_case([100,10,10]).
e_case([0,5,0]).
e_case([0,0,0,0]).
e_case([7,7]).
e_case([2,3,4]).
e_case([6,3,2,0,9]).
e_case([1,2,3,4,5]).

% e_fill(+List, +Values): every element of List is a member of Values.
e_fill([], _).
e_fill([X|Xs], Values) :-
    member(X, Values),
    e_fill(Xs, Values).

% e_lists(+MinLen, +MaxLen, +Values, -Lists): all lists of those lengths over
% Values.
e_lists(MinLen, MaxLen, Values, Lists) :-
    findall(L, ( between(MinLen, MaxLen, N), length(L, N), e_fill(L, Values) ),
            Lists).

% e_must(:Goal, +Info): Goal holds, otherwise the test fails with reason Info.
e_must(Goal, Info) :-
    (   call(Goal)
    ->  true
    ;   throw(test_failed(Info))
    ).

% e_det(:Goal): Goal succeeds and leaves no choice point (Goal must succeed).
e_det(Goal) :-
    call_cleanup(Goal, Det = true),
    (   Det == true
    ->  true
    ;   throw(test_failed(choice_point_left(Goal)))
    ).

% e_count(:Goal, -N): N is the number of solutions of Goal.
e_count(Goal, N) :-
    findall(x, Goal, L),
    length(L, N).

% e_equation_shape(+String): String is a string with no whitespace and exactly
% one "=".
e_equation_shape(String) :-
    string(String),
    string_codes(String, Codes),
    forall(member(C, Codes), \+ code_type(C, space)),
    findall(x, member(0'=, Codes), Equals),
    Equals = [_].

% e_sorted_unique(+List): List is sorted by sort/2 and has no duplicates.
e_sorted_unique(List) :-
    sort(List, Sorted),
    List == Sorted.

% ---------------------------------------------------------------------------
% t_expr_tree
% ---------------------------------------------------------------------------

% t_expr_tree: [] fails; [5] gives exactly n(5) with value 5; the solution
% counts of the spec-style small lists are right; and for the battery lists and
% for every list of length 1..4 over 0..3 the set of Tree-Value solutions equals
% the oracle's, with no duplicate tree, every Value an integer equal to
% expr_value/2 of its Tree.
t_expr_tree :-
    e_must(\+ expr_tree([], _, _), empty_list_has_a_tree),
    findall(T-V, expr_tree([5], T, V), One),
    e_must(One == [n(5)-5], single_number(One)),
    findall(V, expr_tree([6, 3], _, V), V63),
    e_must(V63 == [9, 3, 18, 2], values_6_3(V63)),
    forall(member(List-Count, [[3,6]-3, [5,0]-3, [0,5]-4, [2,2]-4, [6,3]-4]),
           ( e_count(expr_tree(List, _, _), N),
             e_must(N =:= Count, tree_count(List, N, Count)) )),
    e_battery(Battery),
    forall(member(L, [[5], [6,3], [3,6], [5,0], [0,5], [2,2], [6,3,2],
                      [1,2,4,2]|Battery]),
           e_tree_case(L)),
    e_lists(1, 4, [0, 1, 2, 3], Lists),
    forall(member(L, Lists), e_tree_case(L)).

% e_tree_case(+List): expr_tree/3 on List equals the oracle (see t_expr_tree).
e_tree_case(List) :-
    findall(T-V, expr_tree(List, T, V), Got),
    q_trees(List, Expected),
    msort(Got, GotSorted),
    msort(Expected, ExpectedSorted),
    e_must(GotSorted == ExpectedSorted, expr_tree(List, differs_from_oracle)),
    sort(Got, Unique),
    length(Got, N),
    length(Unique, NU),
    e_must(N =:= NU, expr_tree(List, duplicate_trees)),
    forall(member(T-V, Got),
           ( e_must(integer(V), expr_tree(List, not_integer(V))),
             e_must(( expr_value(T, W), W == V ), expr_tree(List, T, value_mismatch(V))) )).

% ---------------------------------------------------------------------------
% t_valid_equation
% ---------------------------------------------------------------------------

% t_valid_equation: fails for [] and one-element lists; for [4,2,5,3] the seven
% equations; pre-bound strings are accepted once when valid and rejected
% otherwise; and for the battery lists and all lists of length 0..4 over 0..3
% the solutions, as a set, equal the oracle's with each solution exactly once
% and every solution a string of the right shape.
t_valid_equation :-
    e_must(\+ valid_equation([], _), empty_list),
    e_must(\+ valid_equation([7], _), one_element),
    e_seven(Seven),
    findall(E, valid_equation([4,2,5,3], E), Got),
    msort(Got, GotSorted),
    e_must(GotSorted == Seven, seven(GotSorted)),
    e_must(e_count(valid_equation([4,2,5,3], "4*2=5+3"), 1), prebound_valid_not_once),
    e_must(\+ valid_equation([4,2,5,3], "4*2=5+4"), prebound_invalid_accepted),
    e_must(e_count(valid_equation([4,2,5,3], "4=2+(5-3)"), 1), prebound_valid_2),
    e_must(\+ valid_equation([4,2,5,3], "4=2+5-4"), prebound_invalid_2),
    e_must(\+ valid_equation([4,2,5,3], "4*2=5+3 "), prebound_with_space),
    e_must(\+ valid_equation([2,3,4], _), no_equation_2_3_4),
    findall(E, valid_equation([2,4,8], E), Got248),
    e_must(Got248 == ["2*4=8"], list_2_4_8(Got248)),
    e_battery(Battery),
    e_lists(0, 4, [0, 1, 2, 3], Lists),
    forall(( member(L, Battery) ; member(L, Lists) ), e_valid_case(L)).

% e_valid_case(+List): valid_equation/2 on List gives the oracle's equations,
% each exactly once, as well-formed strings, and accepts each one pre-bound.
e_valid_case(List) :-
    q_equations(List, Expected),
    findall(E, valid_equation(List, E), Got),
    length(Got, N),
    length(Expected, NE),
    e_must(N =:= NE, valid_equation(List, count(N), expected(NE))),
    sort(Got, GotSorted),
    e_must(GotSorted == Expected, valid_equation(List, differs_from_oracle)),
    e_must(forall(member(E, Got), e_equation_shape(E)), valid_equation(List, bad_shape)),
    forall(member(E, Expected),
           e_must(e_count(valid_equation(List, E), 1), valid_equation(List, prebound, E))).

% ---------------------------------------------------------------------------
% t_generate_equation
% ---------------------------------------------------------------------------

% t_generate_equation: fails for [], one-element lists and [2,3,4]; for
% [4,2,5,3] gives exactly one of the seven; for [2,4,8] gives "2*4=8"; accepts
% every valid pre-bound string exactly once and rejects invalid ones; and for the
% battery lists and all lists of length 0..4 over 0..3 it fails when the oracle
% has no equation and otherwise succeeds exactly once, deterministically, with a
% string that is in the oracle list.
t_generate_equation :-
    e_must(\+ generate_equation([], _), empty_list),
    e_must(\+ generate_equation([7], _), one_element),
    e_must(\+ generate_equation([2,3,4], _), no_equation_2_3_4),
    e_seven(Seven),
    findall(E, generate_equation([4,2,5,3], E), Got),
    e_must(( Got = [S], string(S), memberchk(S, Seven) ), spec_example(Got)),
    findall(E, generate_equation([2,4,8], E), Got248),
    e_must(Got248 == ["2*4=8"], list_2_4_8(Got248)),
    forall(member(E, Seven),
           e_must(e_count(generate_equation([4,2,5,3], E), 1), prebound_valid(E))),
    e_must(\+ generate_equation([4,2,5,3], "4=2+5-4"), prebound_invalid),
    e_must(\+ generate_equation([4,2,5,3], "4*2=5+4"), prebound_invalid_2),
    e_battery(Battery),
    e_lists(0, 4, [0, 1, 2, 3], Lists),
    forall(( member(L, Battery) ; member(L, Lists) ), e_generate_case(L)).

% e_generate_case(+List): see t_generate_equation.
e_generate_case(List) :-
    q_equations(List, Expected),
    findall(E, generate_equation(List, E), Got),
    (   Expected == []
    ->  e_must(Got == [], generate_equation(List, should_fail, Got))
    ;   e_must(( Got = [S], string(S), memberchk(S, Expected) ),
               generate_equation(List, not_one_valid_string, Got)),
        e_det(generate_equation(List, _)),
        forall(member(E, Expected),
               e_must(e_count(generate_equation(List, E), 1),
                      generate_equation(List, prebound, E))),
        Expected = [First|_],
        string_concat(First, "0", Bad),
        e_must(\+ generate_equation(List, Bad), generate_equation(List, accepts_invalid, Bad))
    ).

% ---------------------------------------------------------------------------
% t_all_equations
% ---------------------------------------------------------------------------

% t_all_equations: the spec examples (the seven in the exact spec order, []
% for [2,3,4], ["2*4=8"], [] for [] and one-element lists); the oracle itself
% reproduces the spec (and generates no duplicate string before sorting); the
% result equals the oracle for the battery lists, all lists of length 0..4 over
% 0..3 and all lists of length 5 over 0..1, is sorted and duplicate-free with
% well-formed strings, succeeds exactly once, and the listed 1/2*4-style,
% division-by-zero, negative, zero and multi-digit cases are right; the
% 7-element list [1,2,3,4,5,6,7] finishes in under 20 s of CPU time and equals
% the oracle.
t_all_equations :-
    e_seven(Seven),
    q_equations([4,2,5,3], OracleSeven),
    e_must(OracleSeven == Seven, oracle_seven(OracleSeven)),
    q_equations([2,3,4], O234),
    q_equations([2,4,8], O248),
    e_must(( O234 == [], O248 == ["2*4=8"] ), oracle_other_examples),
    e_battery(Battery),
    forall(member(L, Battery),
           ( q_raw(L, Raw), sort(Raw, RawSorted),
             length(Raw, N), length(RawSorted, NU),
             e_must(N =:= NU, oracle_has_duplicates(L)) )),
    e_must(( all_equations([4,2,5,3], Es), Es == Seven ), spec_seven),
    e_must(( all_equations([2,3,4], E234), E234 == [] ), spec_2_3_4),
    e_must(( all_equations([2,4,8], E248), E248 == ["2*4=8"] ), spec_2_4_8),
    e_must(( all_equations([], E0), E0 == [] ), empty_list),
    e_must(( all_equations([9], E1), E1 == [] ), one_element),
    all_equations([1,2,4,2], E1242),
    e_must(\+ memberchk("1/2*4=2", E1242), remainder_inside_expression),
    all_equations([5,0,0], E500),
    e_must(( \+ memberchk("5/0=0", E500), \+ memberchk("5=0/0", E500) ), division_by_zero),
    all_equations([3,5,1,3], E3513),
    e_must(memberchk("3-5=1-3", E3513), negative_both_sides),
    all_equations([12,3,4], E1234),
    e_must(memberchk("12/3=4", E1234), multi_digit),
    all_equations([10,5,2], E1052),
    e_must(memberchk("10/5=2", E1052), multi_digit_2),
    all_equations([0,5,0], E050),
    e_must(memberchk("0/5=0", E050), zero_dividend),
    all_equations([1,2,3], E123),
    e_must(memberchk("1+2=3", E123), plain_case),
    forall(( member(L, Battery) ; e_lists(0, 4, [0,1,2,3], Ls), member(L, Ls)
           ; e_lists(5, 5, [0,1], Ls5), member(L, Ls5) ),
           e_all_case(L)),
    statistics(cputime, T0),
    all_equations([1,2,3,4,5,6,7], Seven7),
    statistics(cputime, T1),
    T is T1 - T0,
    e_must(T < 20, too_slow(T)),
    q_equations([1,2,3,4,5,6,7], Oracle7),
    e_must(Seven7 == Oracle7, seven_elements_differs_from_oracle),
    e_must(forall(member(E, Seven7), e_equation_shape(E)), seven_elements_bad_shape).

% e_all_case(+List): all_equations/2 on List equals the oracle, is sorted and
% duplicate-free, and succeeds exactly once and deterministically.
e_all_case(List) :-
    q_equations(List, Expected),
    findall(Es, all_equations(List, Es), Solutions),
    e_must(Solutions = [Got], all_equations(List, solutions(Solutions))),
    e_must(Got == Expected, all_equations(List, got(Got), expected(Expected))),
    e_must(e_sorted_unique(Got), all_equations(List, not_sorted_unique)),
    e_must(forall(member(E, Got), e_equation_shape(E)), all_equations(List, bad_shape)),
    e_det(all_equations(List, _)).

% ---------------------------------------------------------------------------
% t_count_equations
% ---------------------------------------------------------------------------

% t_count_equations: the spec-derived counts (7, 0, 1, and 0 for [] and
% one-element lists), then for the battery lists and all lists of length 0..4
% over 0..3 the count is an integer equal to the length of the oracle list, with
% exactly one solution and no choice point.
t_count_equations :-
    forall(member(List-Count, [[4,2,5,3]-7, [2,3,4]-0, [2,4,8]-1, []-0, [9]-0, [0]-0]),
           ( findall(N, count_equations(List, N), Ns),
             e_must(Ns == [Count], count(List, Ns, Count)) )),
    e_battery(Battery),
    e_lists(0, 4, [0, 1, 2, 3], Lists),
    forall(( member(L, Battery) ; member(L, Lists) ), e_count_case(L)).

% e_count_case(+List): see t_count_equations.
e_count_case(List) :-
    q_equations(List, Expected),
    length(Expected, Count),
    findall(N, count_equations(List, N), Ns),
    e_must(Ns == [Count], count(List, Ns, expected(Count))),
    e_must(Ns = [N], count_not_once(List)),
    e_must(integer(N), count_not_integer(List, N)),
    e_det(count_equations(List, _)).

% ---------------------------------------------------------------------------
% Runner
% ---------------------------------------------------------------------------

% e_tests(-Tests): the test predicates, in the order they are run.
e_tests([t_expr_tree, t_valid_equation, t_generate_equation,
         t_all_equations, t_count_equations]).

% e_needs(?Test, ?Units): the predicates (Name/Arity) the test needs defined.
e_needs(t_expr_tree, [expr_tree/3, expr_value/2]).
e_needs(t_valid_equation, [valid_equation/2]).
e_needs(t_generate_equation, [generate_equation/2]).
e_needs(t_all_equations, [all_equations/2]).
e_needs(t_count_equations, [count_equations/2]).

% e_run(+Test, -Result): run one test, print its one line, and give pass, fail
% or missing as Result.
e_run(Test, Result) :-
    (   e_needs(Test, Units),
        member(Name/Arity, Units),
        \+ current_predicate(Name/Arity)
    ->  format("MISSING ~w~n", [Test]),
        Result = missing
    ;   catch(( call(Test) -> Outcome = ok ; Outcome = failed ),
              Error,
              Outcome = raised(Error)),
        e_report(Test, Outcome, Result)
    ).

% e_report(+Test, +Outcome, -Result): print the line for Outcome.
e_report(Test, ok, pass) :-
    format("PASS ~w~n", [Test]).
e_report(Test, failed, fail) :-
    format("FAIL ~w: goal failed~n", [Test]).
e_report(Test, raised(test_failed(Info)), fail) :-
    format("FAIL ~w: ~q~n", [Test, Info]).
e_report(Test, raised(Error), fail) :-
    Error \= test_failed(_),
    format("FAIL ~w: error ~q~n", [Test, Error]).

% t_q2_enum: run all tests; it fails when some test is not PASS.
t_q2_enum :-
    e_tests(Tests),
    findall(R, ( member(T, Tests), e_run(T, R) ), Results),
    forall(member(R, Results), R == pass).
