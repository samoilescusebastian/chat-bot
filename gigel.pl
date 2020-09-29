:- ensure_loaded('chat.pl').

% Returneaza true dacă regula dată ca argument se potriveste cu
% replica data de utilizator. Replica utilizatorului este
% reprezentata ca o lista de tokens. Are nevoie de
% memoria replicilor utilizatorului pentru a deduce emoția/tag-ul
% conversației.

match_rule(Tokens, UserMemory, rule(Expresion, _, _, Emotion, Tag)) :- Expresion = Tokens, get_emotion(UserMemory, Es), ((Es == neutru, Emotion = []); (Emotion = [Es])),
                                                                     get_tag(UserMemory, Tg), ((Tg == none, Tag = []); (Tag = [Tg])).

% Primeste replica utilizatorului (ca lista de tokens) si o lista de
% reguli, iar folosind match_rule le filtrează doar pe cele care se
% potrivesc cu replica dată de utilizator.
find_matching_rules(Tokens, Rules, UserMemory, MatchingRules) :- findall(X, (member(X, Rules), match_rule(Tokens, UserMemory, X)), MatchingRules).

% Intoarce in Answer replica lui Gigel. Selecteaza un set de reguli
% (folosind predicatul rules) pentru care cuvintele cheie se afla in
% replica utilizatorului, in ordine; pe setul de reguli foloseste
% find_matching_rules pentru a obtine un set de raspunsuri posibile.
% Dintre acestea selecteaza pe cea mai putin folosita in conversatie.
%
% Replica utilizatorului este primita in Tokens ca lista de tokens.
% Replica lui Gigel va fi intoarsa tot ca lista de tokens.
%
% UserMemory este memoria cu replicile utilizatorului, folosita pentru
% detectarea emotiei / tag-ului.
% BotMemory este memoria cu replicile lui Gigel și va si folosită pentru
% numararea numarului de utilizari ale unei replici.
%
% In Actions se vor intoarce actiunile de realizat de catre Gigel in
% urma replicii (e.g. exit).
%
% Hint: min_score, ord_subset, find_matching_rules
select_answer(Tokens, UserMemory, BotMemory, Answer, Actions) :-    findall(X, (rules(Keys,X), ord_subset(Keys, Tokens),!), Res), append(Res, Rules),
                                                                    find_matching_rules(Tokens, Rules, UserMemory, MatchingRules),
                                                                    findall(M, (member(X, MatchingRules), X = rule(_, M, _, _, _)), Messages1),
                                                                    append(Messages1, Message2), findall((M, Occ), (member(M, Message2), get_answer(M, BotMemory, Occ)), List), min_element(List, Answer),
                                                                    findall(A,(member(X, MatchingRules), X = rule(_, M, [A], _, _), member(Answer, M)), Actions).

% Esuează doar daca valoarea exit se afla in lista Actions.
% Altfel, returnează true.
handle_actions(Actions) :- \+ (member(X, Actions), X == exit).


% Caută frecvența (numărul de apariți) al fiecarui cuvânt din fiecare
% cheie a memoriei.
% e.g
% ?- find_occurrences(memory{'joc tenis': 3, 'ma uit la box': 2, 'ma uit la un film': 4}, Result).
% Result = count{box:2, film:4, joc:3, la:6, ma:6, tenis:3, uit:6, un:4}.
% Observați ca de exemplu cuvântul tenis are 3 apariți deoarce replica
% din care face parte a fost spusă de 3 ori (are valoarea 3 în memorie).
% Recomandăm pentru usurința să folosiți înca un dicționar în care să tineți
% frecvențele cuvintelor, dar puteți modifica oricum structura, această funcție
% nu este testată direct.
repeat(List, List, N) :- N == 1,!.
repeat(List, NewList, N) :- N1 is N - 1, repeat(List, Result, N1),  append(List, Result, NewList).

add_list_to_map([], Memory, Memory).
add_list_to_map([Head|Rest], OldMemory, Result) :- add_answer([Head], OldMemory, NewMemory), add_list_to_map(Rest, NewMemory, Result).

find_occurrences(UserMemory, Result) :- dict_keys(UserMemory, Keys),
                                        findall(Unrolled, (member(X, Keys), get_value(UserMemory, X, Occ), words(X, Words), repeat(Words, Unrolled, Occ)), IList),
                                        append(IList, FullList), add_list_to_map(FullList, memory{}, Result).

% Atribuie un scor pentru fericire (de cate ori au fost folosit cuvinte din predicatul happy(X))
% cu cât scorul e mai mare cu atât e mai probabil ca utilizatorul să fie fericit.
get_happy_score(UserMemory, Score) :- find_occurrences(UserMemory, Result), dict_keys(Result, Keys),
                                      findall(Ap, (member(X, Keys), get_value(Result, X, Ap), happy(X)), Occs),
                                      sumlist(Occs, Score).

% Atribuie un scor pentru tristețe (de cate ori au fost folosit cuvinte din predicatul sad(X))
% cu cât scorul e mai mare cu atât e mai probabil ca utilizatorul să fie trist.
get_sad_score(UserMemory, Score) :- find_occurrences(UserMemory, Result), dict_keys(Result, Keys),
                                      findall(Ap, (member(X, Keys), get_value(Result, X, Ap), sad(X)), Occs),
                                      sumlist(Occs, Score).
% Pe baza celor doua scoruri alege emoția utilizatorul: `fericit`/`trist`,
% sau `neutru` daca scorurile sunt egale.
% e.g:
% ?- get_emotion(memory{'sunt trist': 1}, Emotion).
% Emotion = trist.
get_emotion(UserMemory, Emotion) :- get_happy_score(UserMemory, HScore), get_sad_score(UserMemory, SScore), 
                                    ((HScore == SScore, Emotion = neutru,!); (HScore > SScore, Emotion = fericit,!); (HScore < SScore, Emotion = trist)).

% Atribuie un scor pentru un Tag (de cate ori au fost folosit cuvinte din lista tag(Tag, Lista))
% cu cât scorul e mai mare cu atât e mai probabil ca utilizatorul să vorbească despre acel subiect.
get_tag_score(Tag, UserMemory, Score) :- find_occurrences(UserMemory, Result), dict_keys(Result, Keys),
                                         findall(Ap, (member(X, Keys), get_value(Result, X, Ap), tag(Tag, List), member(X, List)), Occs),
                                         sumlist(Occs, Score).

% Pentru fiecare tag calculeaza scorul și îl alege pe cel cu scorul maxim.
% Dacă toate scorurile sunt 0 tag-ul va fi none.
% e.g:
% ?- get_emotion(memory{'joc fotbal': 2, 'joc box': 3}, Tag).
% Tag = sport.
get_tag(UserMemory, Tag) :- get_tag_score(sport, UserMemory, STag), get_tag_score(film, UserMemory, Ftag),
                            ((STag == 0, Ftag == 0, Tag = none,!); (STag > Ftag, Tag = sport,!); (Tag = film)).
