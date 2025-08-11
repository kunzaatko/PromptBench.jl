"""
    prompt(t::Trial)
Prompt determined on the factors of the experiment trial and the task.

For a reference implementation see [`prompt(t::Puzzles.Trial)`](@ref)
"""
@interface prompt(::Trial)::PT.AIMessage

# TODO: Set the default to the default of `PromptingTools` <13-07-25> 
"""
    model(t::Trial)
Get the model to use for the trial.

It can use any of the variables that are part of the `Trial` type such including any of the factors.Hence the model could be one of the factors of the experiment (see [`t::Puzzles.Trial`](@ref)).
"""
@interface function model(::Trial)::String
    return PT.get_preferences("MODEL_CHAT")
end

"""
    factors(exp::Experiment)
Get the variable factors of the experiment that may be varied.
"""
@interface factors(::Experiment)

"""
    execute!(t::Trial)
Execute the trial. It must proceed with the trial and store the result within itself. 

The consecutive call of `result(t)` must give the numerical result of the execution of the trial.
"""
@interface execute!(t::Trial)

function PT.aigenerate(t::Trial; kwargs...)
    return PT.aigenerate(prompt(t); model=model(t), kwargs...)
end

"""
    response(t::Trial) 
Get the numerical result/response of the trial `t` (i.e. result of `execute!(t)`).
"""
@interface response(t::Trial)
