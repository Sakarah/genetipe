type filter_pattern =
    | ExactChar of char (** Only the given character is accepted by the filter *)
    | CharRange of (char*char) list (** All characters inside the range is accepted by the filter *)
    | AnyChar (** Any character is accepted by the filter *)
;;

type state =
    | Split of (int * state ref * state ref)
    | Filter of (int * filter_pattern * state ref)
    | Match
;;

type t = (state*int);;

let from_tree regexp_tree =
    let rec connect_ends_to next_state = function
        | [] -> ()
        | end_connection::t -> end_connection := next_state; connect_ends_to next_state t
    in

    let state_count = ref (-1) in

    let rec make_ndfa = function
        | RegexpTree.Concatenation (sub1,sub2) ->
            let (start1,endList1) = make_ndfa sub1 in
            let (start2,endList2) = make_ndfa sub2 in
            connect_ends_to start2 endList1;
            (start1,endList2)
        | RegexpTree.Alternative (alt1,alt2) ->
            let (start1,endList1) = make_ndfa alt1 in
            let (start2,endList2) = make_ndfa alt2 in
            incr state_count;
            (Split (!state_count, ref start1, ref start2), endList1@endList2)
        | RegexpTree.Optional sub ->
            let (start,endList) = make_ndfa sub in
            let newEnd = ref Match in
            incr state_count;
            (Split (!state_count, ref start, newEnd), newEnd::endList)
        | RegexpTree.OneOrMore sub ->
            let (start,endList) = make_ndfa sub in
            let newEnd = ref Match in
            incr state_count;
            let repeatSplit = Split (!state_count, ref start, newEnd) in
            connect_ends_to repeatSplit endList;
            (start,[newEnd])
        | RegexpTree.ZeroOrMore sub ->
            let (start,endList) = make_ndfa sub in
            let newEnd = ref Match in
            incr state_count;
            let repeatSplit = Split (!state_count, ref start, newEnd) in
            connect_ends_to repeatSplit endList;
            (repeatSplit,[newEnd])
        | RegexpTree.ExactChar ch ->
            let newEnd = ref Match in
            incr state_count;
            (Filter (!state_count, ExactChar ch, newEnd), [newEnd])
        | RegexpTree.CharRange range ->
            let newEnd = ref Match in
            incr state_count;
            (Filter (!state_count, CharRange range, newEnd), [newEnd])
        | RegexpTree.AnyChar ->
            let newEnd = ref Match in
            incr state_count;
            (Filter (!state_count, AnyChar, newEnd), [newEnd])
    in

    let (ndfa,_) = make_ndfa regexp_tree in
    (ndfa, !state_count + 1)
;;

let rec in_range ch = function
    | [] -> false
    | (inf,sup)::t when inf <= ch && ch <= sup -> true
    | _::t -> in_range ch t
;;

let rec in_pattern ch = function
    | AnyChar -> true
    | ExactChar c when c = ch -> true
    | CharRange range when in_range ch range -> true
    | _ -> false
;;

let is_matching (first_state,nb_states) str =
    let state_visited = Array.make nb_states false in

    let rec follow_and_visit = function
        | Split (id,_,_) when state_visited.(id) -> []
        | Split (id,s1,s2) -> state_visited.(id) <- true; (follow_and_visit !s1)@(follow_and_visit !s2)
        | Filter (id,_,_) when state_visited.(id) -> []
        | Filter (id,_,_) as state -> state_visited.(id) <- true; [state]
        | state -> [state]
    in

    let rec next_states current_char = function
        | [] -> []
        | Filter (_,pattern,next_state)::t when in_pattern current_char pattern -> (follow_and_visit !next_state)@(next_states current_char t)
        | _::t -> next_states current_char t
    in

    let current_states = ref (follow_and_visit first_state) in
    for i = 0 to String.length str - 1 do
        Array.fill state_visited 0 nb_states false;
        current_states := next_states str.[i] !current_states
    done;
    List.mem Match !current_states
;;

let matching_substrings (first_state,nb_states) str =
    let matched_substrings = ref [] in

    let state_str_start = ref [||] in
    let next_state_str_start = ref (Array.make nb_states (-1)) in

    let rec follow_and_visit string_start string_pos = function
        | Split (id,s1,s2) when !next_state_str_start.(id) = -1 || !next_state_str_start.(id) > string_start ->
            !next_state_str_start.(id) <- string_start;
            (follow_and_visit string_start string_pos !s1)@(follow_and_visit string_start string_pos !s2)
        | Split _ -> []
        | Filter (id,_,_) as state when !next_state_str_start.(id) = -1 -> !next_state_str_start.(id) <- string_start; [state]
        | Filter (id,_,_) when !next_state_str_start.(id) > string_start -> !next_state_str_start.(id) <- string_start; []
        | Filter _ -> []
        | Match when string_pos = string_start -> [] (* We want to avoid empty substrings *)
        | Match -> matched_substrings := (string_start,string_pos)::(!matched_substrings); []
    in

    let rec next_states string_pos = function
        | [] -> follow_and_visit string_pos string_pos first_state
        | Filter (id,pattern,next_state)::t when in_pattern str.[string_pos-1] pattern ->
            (follow_and_visit !state_str_start.(id) string_pos !next_state)@(next_states string_pos t)
        | _::t -> next_states string_pos t
    in

    let current_states = ref (follow_and_visit 0 0 first_state) in
    for i = 1 to String.length str do
        state_str_start := !next_state_str_start;
        next_state_str_start := Array.make nb_states (-1);
        current_states := next_states i !current_states
    done;

    let start_of_string_found = Array.make (String.length str) false in
    let rec remove_useless_substrings = function
        | [] -> []
        | (s,_)::t when start_of_string_found.(s) -> remove_useless_substrings t
        | (s,e)::t -> start_of_string_found.(s) <- true; (s,e)::(remove_useless_substrings t)
    in
    remove_useless_substrings !matched_substrings
;;
