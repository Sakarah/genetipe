(** Evolver contains all the functions related to creation and then evolution
    of a population. It implements natural selection mechanics and manage the
    population growth by mutation and crossover.
    You can create a new evolver from any EvolParams module using {!Make}. *)

(** Module signature of an evolver *)
module type S =
sig
    (** Type of the evolved individuals *)
    type individual

    (** Type of the fitness values*)
    type fitness

    (** Type of the target data*)
    type target_data

    (** Initialize the population with randomly generated individuals *)
    val init_population : target_data -> (fitness option * individual) array

    (** Compute the fitness of all the individuals of a population *)
    val compute_fitness : target_data -> (fitness option * individual) array -> (fitness * individual) array

    (** Simplify all the individuals from the given population *)
    val simplify_individuals : ?generation:int -> (fitness option * individual) array -> (fitness option * individual) array

    (** Recombine existing individuals and make mutations to create new functions *)
    val reproduce : target_data -> (fitness * individual) array -> (fitness option * individual) array

    (** Filter the input population to reach the given size by using the selection function *)
    val select : (fitness * individual) array -> target_size:int -> (fitness * individual) array

    (** Replace duplicates by new randomly generated individuals *)
    val remove_duplicates : target_data -> (fitness option * individual) array -> (fitness option * individual) array

    (** Evolve the population to the next generation *)
    val next_generation : target_data -> ?generation:int -> (fitness * individual) array -> (fitness * individual) array

    (** Evolve a population through nb_gen generations toward the highest fitness on the given target data.
        If init_pop is not given, the population is randomly initialized (with {!init_population}).
        If a verbosity option is given, write details about the evolution on the standard output. *)
    val evolve : ?init_pop:(fitness * individual) array -> nb_gen:int -> ?verbosity:int -> target_data -> (fitness * individual) array
end

(** Create a new Evolver from the given parameters *)
module Make : functor (Parameters : EvolParams.S) -> S with type individual := Parameters.Individual.t and type target_data := Parameters.target_data and type fitness := Parameters.Fitness.t
