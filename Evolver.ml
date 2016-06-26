let init_population () =
    let rand_gen_func = (Parameters.get()).Parameters.creation in
    let size = (Parameters.get()).Parameters.pop_size in
    let max_depth = (Parameters.get()).Parameters.max_depth in
    Array.init size (function i -> (None, Dna.create_random rand_gen_func ~max_depth:((max_depth*i)/size)))
;;

let compute_fitness points =
    let fillFitness = function
        | (None,dna) -> ((Parameters.get()).Parameters.fitness points dna, dna)
        | (Some fitness,dna) -> (fitness, dna)
    in
    Array.map fillFitness
;;

let simplify_individuals ?generation pop =
    let apply_simplification pop (schedule,simpl) =
        match generation with
        | Some g when schedule mod g <> 0 -> pop
        | _ -> Array.map (function (fit,dna) -> (fit,simpl dna)) pop
    in
    List.fold_left apply_simplification pop (Parameters.get()).Parameters.simplifications
;;

let shuffle initial_population =
    let size = Array.length initial_population in
    for i=0 to (size-2) do
        let invPos = i + 1 + Random.int (size-i-1) in
        let switch = initial_population.(i) in
        initial_population.(i) <- initial_population.(invPos);
        initial_population.(invPos) <- switch
    done
;;

let tournament initial_population ~target_size =
    let size = Array.length initial_population in
    let winners = Array.make target_size initial_population.(0) in
    let n_fill_in = 2* target_size - size in
    shuffle initial_population;
    for i = 0 to (n_fill_in - 1) do
        winners.(i) <- initial_population.(i)
    done;
    for i = 0 to (target_size - n_fill_in - 1) do
        if (fst initial_population.(n_fill_in + 2*i)) > (fst initial_population.(n_fill_in + 2*i+1)) then
            winners.(n_fill_in + i) <- initial_population.(n_fill_in + 2*i)
        else winners.(n_fill_in + i) <- initial_population.(n_fill_in + 2*i+1)
    done;
    winners
;;

let tournament_by_packs population ~target_size =
    let pop_size = Array.length population in
    let pack_size = int_of_float(ceil (float_of_int(pop_size)/.float_of_int(target_size))) in
    let selected_dna = Array.make target_size population.(0) in
    shuffle population;
    for i = 0 to (target_size - 2) do
        let index = pack_size * i in
        let selected_index = ref index in
        for j = 1 to pack_size do
            if fst population.(index + j) > fst population.(!selected_index) then
            (
                selected_index := index + j
            )
        done;
        selected_dna.(i) <- population.(!selected_index)
    done;
    let index = pack_size * (target_size - 1) in
    let selected_index = ref index in
    for j = 0 to (pop_size - pack_size * (target_size - 1) - 1)  do
        if fst population.(index + j) > fst population.(!selected_index) then
            (
                selected_index := index + j
            )
    done;
    selected_dna.(target_size - 1) <- population.(!selected_index);
    selected_dna
;;

let reproduce initial_population =
    let pop_size = Array.length initial_population in
    let fitness_total = ref 0. in
    let fitness_cumul = Array.init pop_size (function i -> fitness_total := !fitness_total +. (fst initial_population.(i)); !fitness_total) in
    let evolution_params = Parameters.get () in

    let target_size = int_of_float(float_of_int pop_size *. evolution_params.Parameters.growth_factor) in
    let target_population = Array.make target_size (None, snd initial_population.(0)) in

    (* Copy the previous individuals in the target population *)
    for i = 0 to pop_size-1 do
        let (fitness,dna) = initial_population.(i) in
        target_population.(i) <- (Some fitness, dna)
    done;

    (* Return the individual matching with the random number according to their fitness (more chances to get better graded ones) *)
    let individual_from_rand value =
        (* Return the index of the first cumulative fitness above value *)
        let rec first_above i j = (* i included j excluded convention *)
            if i=j then i
            else
            (
                let k = (i+j)/2 in
                if fitness_cumul.(k) < value then
                    first_above (k+1) j
                else
                    first_above i k
            )
        in
        snd initial_population.(first_above 0 pop_size)
    in

    (* The rest of the array is filled with generated offsprings *)
    for i = pop_size to target_size - 1 do
        let parent_dna = individual_from_rand (Random.float !fitness_total) in
        if evolution_params.Parameters.mutation_ratio < Random.float 1. then
            target_population.(i) <- (None, Dna.mutation evolution_params.Parameters.mutation ~max_depth:evolution_params.Parameters.max_depth parent_dna)
        else
            let second_parent_dna = individual_from_rand (Random.float !fitness_total) in
            target_population.(i) <- (None, Dna.crossover evolution_params.Parameters.crossover parent_dna second_parent_dna)
    done;
    target_population
;;

let evolve points initial_population =
    let pop_size = Array.length initial_population in
    let child_population = reproduce initial_population in
    let evaluated_population = compute_fitness points child_population in
    tournament evaluated_population ~target_size:pop_size
;;
