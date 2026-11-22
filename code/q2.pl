% apply_op(+Op, +A, +B, -Value): Value is the integer result of applying the
% binary operator Op (one of '+', '-', '*', '/') to the integers A and B.
% For '/', it holds only when B =\= 0 and A is exactly divisible by B, and
% Value is then the integer quotient A/B. For any other Op it does not hold.
apply_op('+', A, B, Value) :-
    Value is A + B.
apply_op('-', A, B, Value) :-
    Value is A - B.
apply_op('*', A, B, Value) :-
    Value is A * B.
apply_op('/', A, B, Value) :-
    B =\= 0,
    A mod B =:= 0,
    Value is A // B.

% expr_value(+Tree, -Value): Value is the integer value of the expression tree
% Tree, where n(V) has value V and e(Op, L, R) has the value obtained by
% applying Op (by apply_op/4) to the values of L and R. It holds only if every
% operation inside Tree is allowed by apply_op/4, so any inexact or
% zero-divisor division anywhere in Tree makes it fail.
expr_value(n(Value), Value).
expr_value(e(Op, Left, Right), Value) :-
    expr_value(Left, LeftValue),
    expr_value(Right, RightValue),
    apply_op(Op, LeftValue, RightValue, Value).

% expr_string_prec(+Op, -Prec): Prec is the precedence level of the operator
% Op: 1 for '+' and '-', 2 for '*' and '/' (a higher level binds tighter).
expr_string_prec('+', 1).
expr_string_prec('-', 1).
expr_string_prec('*', 2).
expr_string_prec('/', 2).

% expr_string_parens(+Side, +ParentPrec, +Tree): an operand Tree on the side
% Side (left or right) of an operator of precedence ParentPrec must be written
% in parentheses: a left operand if its top operator has lower precedence than
% the parent's, a right operand if its top operator has the same or lower
% precedence. A single number n(_) never needs them (no clause matches).
expr_string_parens(left, ParentPrec, e(Op, _, _)) :-
    expr_string_prec(Op, Prec),
    Prec < ParentPrec.
expr_string_parens(right, ParentPrec, e(Op, _, _)) :-
    expr_string_prec(Op, Prec),
    Prec =< ParentPrec.

% expr_string_operand(+Side, +ParentPrec, +Tree, -String): String is the
% canonical string of the operand Tree, enclosed in parentheses exactly when
% expr_string_parens/3 holds for Side, ParentPrec and Tree.
% The if-then-else is used because "parentheses or not" is a two-way choice on
% a test that must not leave a choice point.
expr_string_operand(Side, ParentPrec, Tree, String) :-
    expr_string(Tree, Inner),
    (   expr_string_parens(Side, ParentPrec, Tree)
    ->  format(string(String), "(~w)", [Inner])
    ;   String = Inner
    ).

% expr_string(+Tree, -String): String is the SWI-Prolog string of the
% expression tree Tree with no spaces: n(V) is V in decimal, and e(Op, L, R) is
% the string of L, then Op, then the string of R, where L and R are
% parenthesised by expr_string_parens/3 (operators left-associative, * and /
% tighter than + and -). The tree is not evaluated.
expr_string(n(Value), String) :-
    format(string(String), "~d", [Value]).
expr_string(e(Op, Left, Right), String) :-
    expr_string_prec(Op, Prec),
    expr_string_operand(left, Prec, Left, LeftString),
    expr_string_operand(right, Prec, Right, RightString),
    format(string(String), "~w~w~w", [LeftString, Op, RightString]).

% equation_string(+LTree, +RTree, -String): String is the SWI-Prolog string
% made of the expr_string/2 string of LTree, then the character "=", then the
% expr_string/2 string of RTree. Neither tree is evaluated and the two sides
% need not be equal.
equation_string(LTree, RTree, String) :-
    expr_string(LTree, LString),
    expr_string(RTree, RString),
    format(string(String), "~w=~w", [LString, RString]).

:- use_module(library(lists)).

% expr_tree_op(?Op): Op is one of the four operators '+', '-', '*', '/'.
expr_tree_op('+').
expr_tree_op('-').
expr_tree_op('*').
expr_tree_op('/').

% expr_tree(+Numbers, -Tree, -Value): Tree is an expression tree whose leaves
% are, left to right, exactly the elements of Numbers (each used once, in
% order), and Value is the integer value of Tree, where every operation in Tree
% is allowed by apply_op/4. A single number N gives n(N) with Value N. A longer
% list is split into a non-empty prefix and a non-empty suffix, the two parts
% give subtrees L and R, and the tree is e(Op, L, R) for any operator Op whose
% apply_op/4 holds for the two values. Different splits, operators and subtrees
% give different trees, so every valid tree is a solution exactly once; [] has
% no solution.
expr_tree([Number], n(Number), Number).
expr_tree(Numbers, e(Op, Left, Right), Value) :-
    Numbers = [_, _|_],
    append(LeftNumbers, RightNumbers, Numbers),
    LeftNumbers = [_|_],
    RightNumbers = [_|_],
    expr_tree(LeftNumbers, Left, LeftValue),
    expr_tree(RightNumbers, Right, RightValue),
    expr_tree_op(Op),
    apply_op(Op, LeftValue, RightValue, Value).

% valid_equation(+List, ?Equation): Equation is the string of an equation L=R
% for List, that is, List splits into a non-empty prefix and a non-empty suffix,
% L is an expression tree over the prefix and R one over the suffix (see
% expr_tree/3), both have the same integer value, and Equation is the string of
% L and R given by equation_string/3. Every (split, L, R) with equal values
% gives one solution; a list with fewer than two numbers has none.
valid_equation(List, Equation) :-
    List = [_, _|_],
    append(LeftNumbers, RightNumbers, List),
    LeftNumbers = [_|_],
    RightNumbers = [_|_],
    expr_tree(LeftNumbers, LeftTree, Value),
    expr_tree(RightNumbers, RightTree, Value),
    equation_string(LeftTree, RightTree, Equation).

% generate_equation(+List, ?Equation): Equation is the string of some valid
% equation for List, i.e. valid_equation(List, Equation) holds; it holds for at
% most one Equation (the first one found), and not at all if List has none.
% once/1 is used because the spec asks for a single answer with no choice
% point; it also stops the search at the first valid equation.
generate_equation(List, Equation) :-
    once(valid_equation(List, Equation)).

% all_equations(+List, -Equations): Equations is the list of all strings Equation
% for which valid_equation(List, Equation) holds, without duplicates and in the
% standard order of terms (sort/2); it is [] when List has no valid equation.
% findall/3 is used so that the result is one list and always succeeds.
all_equations(List, Equations) :-
    findall(Equation, valid_equation(List, Equation), Found),
    sort(Found, Equations).

% count_equations(+List, -N): N is the number of elements of the list Equations
% for which all_equations(List, Equations) holds, i.e. the number of different
% valid equations of List.
count_equations(List, N) :-
    all_equations(List, Equations),
    length(Equations, N).
