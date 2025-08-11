using PromptBench
using Test, Aqua, CompatHelperLocal

const run_all = isempty(ARGS) ? true : false

skip = Dict{String,Bool}(
    "compat" => !(VERSION >= v"1.9"), # NOTE: `CompatHelperLocal` only compatible with later Julia version <28-02-25> 
    "aqua" => !haskey(ENV, "GITHUB_ACTIONS") && !haskey(ENV, "RUNTESTS_FULL"),
    "doctests" => !haskey(ENV, "RUNTESTS_FULL") && !(haskey(ENV, "RUNNER_OS") && ENV["RUNNER_OS"] == "Linux"),
    "ambiguities" => true
)

function should_test(arg::String)::Bool
    global run_all
    if run_all
        return !get(skip, arg, false)
    elseif arg in ARGS
        return true
    end
    return false
end

macro cond_testset(name, block)
    quote
        if should_test($name)
            @testset $name begin
                esc($block)
            end
        end
    end
end

@testset "PromptBench.jl" begin
    @testset "Code quality" begin
        @cond_testset "aqua" begin
            Aqua.test_all(PromptBench;
                ambiguities=false,
            )
        end

        @cond_testset "ambiguities" begin
            aqua_ambiguities = false
            if aqua_ambiguities
                Agua.test_ambiguities(PromptBench)
            else
                @test length(Test.detect_ambiguities(PromptBench)) == 0
            end
        end

        @cond_testset "compat" begin
            @test CompatHelperLocal.check(PromptBench; checktest=false)
        end
    end

    @cond_testset "doctests" begin
        # NOTE: Better than doc-testing in `make.jl` because, I can track the coverage
        # NOTE: When updating, must update also in `docs/make.jl` <30-05-25> 
        DocMeta.setdocmeta!(ZebraPuzzles, :DocTestSetup, :(
                include(joinpath(@__DIR__, "doctestsetup.jl"));
                # NOTE: Not necessary in `../docs/make.jl`. `@warn` should work there <30-05-25> 
                using Logging;
                Logging.disable_logging(Logging.Warn)
            ); recursive=true)
        !haskey(ENV, "FIX_DOCTESTS") && @info "You can fix doctests by setting `ENV[\"FIX_DOCTESTS\"] = true`."
        apply(pretty_tables_patch) do
            doctest(ZebraPuzzles; fix=ifelse(haskey(ENV, "FIX_DOCTESTS"), true, false))
        end
    end
end
