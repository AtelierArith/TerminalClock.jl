using Test

using TerminalClock: n2d, colon, createclock
using Dates

@testset "Dial" begin
    for n in 0:9
        @test length(split(n2d(n).str, "\n")) == 9
        @test length(split(n2d(n), "\n")) == 9
    end
    @test length(split(colon, "\n")) == 9
end

@testset "hcat" begin
    d1 = hcat(n2d(1), n2d(2))
    @test length(split(d1, "\n")) == 9

    d2 = hcat(n2d(1), n2d(2), colon, n2d(3), n2d(4))
    @test length(split(d2, "\n")) == 9
end

@testset "createclock" begin
    dt = DateTime(2021,11,15,12,34,56,7)
    str = createclock(dt)
    @test str == join(readlines("clock.txt"), "\n")
end