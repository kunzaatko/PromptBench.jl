using PromptBench
using Test
using Aqua

@testset "PromptBench.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(PromptBench)
    end
    # Write your tests here.
end
