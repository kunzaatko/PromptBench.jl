module PromptBench
using PromptingTools, DotEnv, InterfaceFunctions
using PromptingTools: PromptingTools as PT

function __init__()
    DotEnv.load!(; override=true)
    return nothing
end

const Option{T} = Union{Missing,T}
issome(x::Option) = !ismissing(x)

const PROMPT_DIR = normpath(joinpath(@__DIR__, "..", "prompts/"))

# TODO: State the interfaces that must be implemented <25-06-25> 
"""
    Experiment
An abstract type that defines an experiment that can be executed.

For an example implementation, see [`PuzzleExperiment`](@ref)
"""
abstract type Experiment end

"""
    Trial{E<:Experiment}
An abstract type that defines a trial of an experiment.

For an example implementation, see [`PuzzleTrial`](@ref)
"""
abstract type Trial{E<:Experiment} end

"""
    TrialResult{T} 
Result of a trial of an experiment. `T` has to be numerical.
"""
struct TrialResult{T}
    value::T
end
value(r::TrialResult) = r.value

include("interfaces.jl")
include("zebra-puzzles.jl")

end
