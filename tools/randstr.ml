let () =
    let nb_str = ref (-1) in
    let alph_range = ref "a-z" in
    let min_length = ref 3 in
    let max_length = ref 20 in

    let spec_list =
    [
        ("--len-range", Arg.Tuple [Arg.Set_int min_length ; Arg.Set_int max_length], " Set the range of length of the generated strings (default is [3,20])");
        ("-l", Arg.Tuple [Arg.Set_int min_length ; Arg.Set_int max_length], " Shorthand for --len-range");
        ("--rand", Arg.Int (function r -> Random.init r), " Set the random seed");
        ("-r", Arg.Int (function r -> Random.init r), " Shorthand for --rand");
        ("--nb-str", Arg.Set_int nb_str, " Set the number of strings to generate (default is infinity)");
        ("-n", Arg.Set_int nb_str, " Shorthand for --nb-str")
    ]
    in

    let usage_msg =
        "Generate a totally random list of strings taking chars form the given alphabet (or lower-case ASCII by default).\n\
        The alphabet can be given with ranges like a-zA-z.\n\
        Running the program with the same parameters will give the same result. You have to change the seed to create another dataset.\n\
        Usage : randstr [options] alphabet\n\
        \n\
        Options available:"
    in

    Arg.parse (Arg.align spec_list) (fun alph -> alph_range := alph) usage_msg;

    let string_range start_char stop_char =
        String.init (int_of_char stop_char - int_of_char start_char + 1) (fun i -> char_of_int (i + int_of_char start_char))
    in
    let rec parse_alphabet pos =
        if pos = String.length !alph_range then ""
        else
        (
            if pos < String.length !alph_range - 2 && !alph_range.[pos+1] = '-' then
                (string_range !alph_range.[pos] !alph_range.[pos+2]) ^ (parse_alphabet (pos+3))
            else
                (String.make 1 !alph_range.[pos]) ^ (parse_alphabet (pos+1))
        )
    in
    let alphabet = parse_alphabet 0 in

    while !nb_str <> 0 do
        let size = !min_length + Random.int (!max_length - !min_length) in
        let str = Bytes.create size in
        for i = 0 to size-1 do
            Bytes.set str i alphabet.[Random.int (String.length alphabet)]
        done;
        Printf.printf "%s\n" (Bytes.to_string str);

        if !nb_str <> -1 then decr nb_str
    done;
;;
