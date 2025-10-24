# TODO: Add serialization into json and txt files for the conversations so that I can record the experimental data <15-07-25> 
# TODO: Add an ExperimentVariables type that could extend the functionality of ExperimentalDesign <12-07-25> 
module Puzzles
import PromptBench as PB
import PromptBench: prompt, model, response, execute!
using PromptBench: Option, model, issome, value
using ZebraPuzzles,
    CategoricalArrays,
    OteraEngine,
    Missings,
    DataAPI,
    PromptingTools,
    Random,
    PrettyTables,
    DataFrames
using ZebraPuzzles: ZebraPuzzles as ZP
using PromptingTools: PromptingTools as PT

const PROMPT_DIR = joinpath(PB.PROMPT_DIR, "zebra-puzzles")
const PromptVars = @NamedTuple{
    hasrole::Bool,
    hasexamples::Bool, # TODO: Convert this to a number of examples instead <15-07-25> 
    hasstrategy::Bool,
    hasterminology::Bool,
    haschainofthought::Bool,
}
function default(::Type{PromptVars})
    return (;
        hasrole=false,
        hasexamples=false,
        hasstrategy=false,
        hasterminology=false,
        haschainofthought=false,
    )
end

"""
    Experiment  <: PB.Experiment
An experiment that asks the LLM to solve a logical zebra puzzle with `K` puzzle subjects and `N` attributes per subject.

The variables that can be set in the experiment and are the factors that must be considered
"""
mutable struct Experiment <: PB.Experiment
    trials::Vector # Trials
end

"""
    TrialResult
The outcome of the answer of the LLM to the logical zebra puzzle.

The `value` field indicates whether the puzzle was answered correctly by the model. If the answer is CORRECT then `value==true`. If the answer is INCORRECT, then `value==false`.
"""
const TrialResult = PB.TrialResult{Bool}

const MODELS = CategoricalArray([
    "gemini-2.0-flash",
    "deepseek-chat",
    "deepseek-reasoner",
    "gpt-4.1-mini",
    # "grok-beta",
    "claude-3-7-sonnet-latest",
])

"""
    TrialSettings{PV}
Settings of the LLM trial for a zebra puzzle. It includes the `puzzle` to be solved by the model and `vars` which are
the variables that determine the prompt.
"""
@kwdef struct TrialSettings{PV}
    puzzle::ZebraPuzzle
    puzzle_string::Option{String} = missing # puzzle string must be identical for all trials with one puzzle
    vars::PV
    model::CategoricalValue = CategoricalValue("deepseek-chat", MODELS)
    function TrialSettings(p, ps, v, m)
        ZP.issolved(p) || solve!(p)
        ps = ismissing(ps) ? ZP.riddle(p; quiet=true) : ps
        return new{typeof(v)}(p, ps, v, m)
    end
end

function Base.show(io::IO, t::TrialSettings)
    printstyled(io, "Settings:\n"; bold=true)
    return pretty_table(
        io,
        DataFrame(
            merge(
                Dict(
                    :nsubjects => DataAPI.nrow(t.puzzle),
                    :nattributes => DataAPI.ncol(t.puzzle),
                    :nclues => nclue(t.puzzle),
                    :model => t.model,
                ),
                Dict(pairs(t.vars)),
            ),
        );
        alignment=:c,
        table_format=TextTableFormat(;
            vertical_lines_at_data_columns=:none, horizontal_lines_at_data_rows=:all
        ),
        style=TextTableStyle(; first_line_column_label=crayon"yellow bold"),
        # show_subheader=false, FIX: Must be solved by defining the labels of the pretty-table <24-10-25> 
    )
end

# TODO: Add nuisance variables extracted from the trial such as `number of clues`, position/attribute questions,
# question attributes, number of different clue variants etc. <15-07-25> 

"""
    Trial{V} <: PB.Trial{PuzzleExperiment{<:Any,<:Any,V}}
A trial of the LLM to solve a logical zebra puzzle.
"""
@kwdef mutable struct Trial{V} <: PB.Trial{Experiment}
    settings::TrialSettings{V}
    output::Option{AIMessage} = missing
    summary::Option{AIMessage} = missing
    result::Option{TrialResult} = missing
end
Trial(settings::TrialSettings; kwargs...) = Trial(; settings, kwargs...)
puzzle(t::Trial) = t.settings.puzzle
ZP.riddle(t::Trial) = (print(t.settings.puzzle_string); return t.settings.puzzle_string)
output(t::Trial) = t.output
summary(t) = t.summary.content
response(t::Trial) = ismissing(t.result) ? missing : value(t.result)
model(t::Trial) = String(t.settings.model)

function Random.rand(::Type{Trial}, K::Int=4, N::Int=4; vars=default(PromptVars), kwargs...)
    puzzle = rand(UnsolvedZebraPuzzle{K,N})
    vars = merge(vars, filter(a -> a[1] in fieldnames(PromptVars), kwargs))
    settings = TrialSettings(; puzzle, vars)
    return Trial(settings)
end

function Base.show(io::IO, t::Trial)
    Base.printstyled(io, "Puzzles trial with:"; color=:blue, bold=true)
    print(io, "\n- ")
    Base.show(io, t.settings)
    if issome(output(t))
        print(io, "\n")
        printstyled(io, "- Output"; bold=true)
        print(io, " (" * string(countlines(IOBuffer(output(t).content))) * " lines)")
        if issome(t.summary)
            print(io, ":\n  -> Summary: ")
            printstyled(io, "\"$(summary(t))\"\n"; italic=true)
        end
    end
    if issome(response(t))
        print(io, "\n")
        printstyled(io, "- Response:\n"; bold=true)
        print(io, "  -> ")
        printstyled(io, response(t); italic=true)
    end
end

"""
    prompt(z::Puzzles.Trial)
Get the prompt for the trial of the experiment.
"""
function prompt(z::Trial)
    prompt_tmp = Template(joinpath(PROMPT_DIR, "prompt.j2"))
    prompt = prompt_tmp(;
        init=merge(Dict(:puzzle => z.settings.puzzle_string), Dict(pairs(z.settings.vars)))
    )
    return prompt
end

# NOTE: Using "gemini-2.0-flash" because it is a reliant, fast and free model <14-07-25> 
"""
    check_answer!(t::Puzzles.Trial; model="gemini-2.0-flash")
Checks the answer of the trial based on the model output in `t.output` (cannot be missing) and stores it in `t.result`
"""
function check_answer!(t::Trial; model="gemini-2.0-flash")
    @assert issome(t.output) "Output messege must be present"
    out_message = t.output
    summarize_tmp = Template(joinpath(PROMPT_DIR, "summarize-answer.j2"))()
    summary = aigenerate(
        [PT.SystemMessage(summarize_tmp), PT.UserMessage(out_message)]; model
    )
    t.summary = summary
    @assert length(puzzle(t).questions) == 1 "There should be only one question"
    @assert ZP.issolved(puzzle(t)) "The puzzle should be solved by now"
    correct = ZP.answer(first(puzzle(t).questions), puzzle(t))
    check_tmp = Template(joinpath(PROMPT_DIR, "check-answer.j2"))
    check_prompt = check_tmp(;
        init=Dict(
            :question => ZP.phrase(first(puzzle(t).questions)),
            :submitted => summary.content,
            :solution => correct,
        ),
    )
    verdict = aiextract(check_prompt; return_type=TrialResult, model)
    t.result = verdict.content
    return verdict.content
end

function execute!(t::Puzzles.Trial)
    if ismissing(t.output)
        @info "Generating trial output..."
        solution = aigenerate(t; http_kwargs=(; readtimeout=0))
        t.output = solution
    else
        @info "Reusing trial output..."
    end
    if ismissing(t.result)
        @info "Checking trial answer..."
        check_answer!(t)
    else
        @info "Reusing trial answer..."
    end
    return t
end

end # module PuzzleExperiment
