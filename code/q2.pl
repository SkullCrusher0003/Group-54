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
