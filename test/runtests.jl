using Test

using TerminalClock: n2d, colon

@testset "Dial" begin
    for n in 0:9
        @test length(split(n2d(n).str, "\n")) == 10
        @test length(split(n2d(n), "\n")) == 10
    end
    @test length(split(colon, "\n")) == 10
end

@testset "hcat" begin
    d1 = hcat(n2d(1), n2d(2))
    @test length(split(d1, "\n")) == 10

    d2 = hcat(n2d(1), n2d(2), colon, n2d(3), n2d(4))
    @test length(split(d2, "\n")) == 10
end