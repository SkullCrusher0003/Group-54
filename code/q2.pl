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
