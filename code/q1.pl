:- use_module(library(lists)).

% candidate(?Solution): Solution is a list of four terms p(Name, Dept, Lang, Project)
% whose names are 'Alex', 'Ben', 'Carla', 'Dana' in that order, and whose Dept
% values, Lang values and Project values are each a permutation of the four
% departments, the four languages and the four projects respectively.
candidate([p('Alex', D1, L1, P1),
           p('Ben',  D2, L2, P2),
           p('Carla', D3, L3, P3),
           p('Dana', D4, L4, P4)]) :-
    permutation([research, development, design, testing], [D1, D2, D3, D4]),
    permutation([python, java, 'c++', javascript], [L1, L2, L3, L4]),
    permutation(['AI', web, embedded, data], [P1, P2, P3, P4]).

% clue(+N, +Solution)
% CLUE 1: The friend who prefers the AI project does not work in research and is not Dana.
clue(1, Solution) :-
    memberchk(p(Name, Dept, _, 'AI'), Solution),
    Dept \== research,
    Name \== 'Dana'.

% CLUE 2: Alex does not work in development and does not prefer C++.
clue(2, Solution) :-
    memberchk(p('Alex', Dept, Lang, _), Solution),
    Dept \== development,
    Lang \== 'c++'.

% CLUE 3: The friend working in the testing department likes Python.
clue(3, Solution) :-
    memberchk(p(_, testing, Lang, _), Solution),
    Lang == python.

% CLUE 4: Ben prefers web projects and does not work in testing.
clue(4, Solution) :-
    memberchk(p('Ben', Dept, _, Project), Solution),
    Project == web,
    Dept \== testing.

% CLUE 5: The friend whose favorite language is Java works in the design department.
clue(5, Solution) :-
    memberchk(p(_, Dept, java, _), Solution),
    Dept == design.

% CLUE 6: Carla's project preference is not embedded, and her department is not development.
clue(6, Solution) :-
    memberchk(p('Carla', Dept, _, Project), Solution),
    Project \== embedded,
    Dept \== development.

% CLUE 7: Dana's favorite language is not Java, and she works in research or testing.
clue(7, Solution) :-
    memberchk(p('Dana', Dept, Lang, _), Solution),
    Lang \== java,
    ( Dept == research ; Dept == testing ).

% CLUE 8: The friend who prefers data projects works in research and does not use JavaScript.
clue(8, Solution) :-
    memberchk(p(_, Dept, Lang, data), Solution),
    Dept == research,
    Lang \== javascript.

% CLUE 9: The friend who prefers the AI project likes Python.
clue(9, Solution) :-
    memberchk(p(_, _, Lang, 'AI'), Solution),
    Lang == python.

% clues_hold(+Active, +Solution): every clue whose number is in the list Active
% holds in Solution; clues not in Active are not considered.
clues_hold(Active, Solution) :-
    forall(member(N, Active), clue(N, Solution)).
