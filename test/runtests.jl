using Test

using TerminalClock
using TerminalClock: n2d, colon
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

@testset "clock" begin
    dt = DateTime(2021,11,15,12,34,56,7)
    str = clock(dt)
    txt = joinpath("references", "clock.txt")
    @test str == join(readlines(txt), "\n")
end

@testset "stopwatch" begin
    t = Time(12,34,56,789)
    str = stopwatch(t)
    txt = joinpath("references", "stopwatch.txt")
    @test str == join(readlines(txt), "\n")
end