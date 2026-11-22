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
