using Test

using TerminalClock
using TerminalClock: n2d, COLON_LARGE, setup_timer
using Dates
using TOML

# Taken from Prefernces.jl/test/runtests.jl
function with_temp_depot(f::Function)
    mktempdir() do dir
        saved_depot_path = copy(Base.DEPOT_PATH)
        empty!(Base.DEPOT_PATH)
        push!(Base.DEPOT_PATH, dir)
        try
            f()
        finally
            empty!(Base.DEPOT_PATH)
            append!(Base.DEPOT_PATH, saved_depot_path)
        end
    end
end

# Taken from Prefernces.jl/test/runtests.jl
function activate_and_run(project_dir::String, code::String; env::Dict = Dict())
    mktempdir() do dir
        open(joinpath(dir, "test_code.jl"), "w") do io
            write(io, code)
        end

        out = Pipe()
        cmd = setenv(`$(Base.julia_cmd()) --project=$(project_dir) $(dir)/test_code.jl`,
                     env..., "JULIA_DEPOT_PATH" => Base.DEPOT_PATH[1])
        p = run(pipeline(cmd, stdout=out, stderr=out); wait=false)
        close(out.in)
        wait(p)
        output = String(read(out))
        if !success(p)
            println(output)
        end
        @test success(p)
        return output
    end
end

@testset "Dial" begin
    for n = 0:9
        @test length(split(n2d(n).str, "\n")) == 9
        @test length(split(n2d(n), "\n")) == 9
    end
    @test length(split(COLON_LARGE, "\n")) == 9
end

@testset "hcat" begin
    d1 = hcat(n2d(1), n2d(2))
    @test length(split(d1, "\n")) == 9

    d2 = hcat(n2d(1), n2d(2), COLON_LARGE, n2d(3), n2d(4))
    @test length(split(d2, "\n")) == 9
end

@testset "clock" begin
    dt = DateTime(2021, 11, 15, 12, 34, 56, 7)
    str = clock(dt)
    txt = joinpath("references", "clock.txt")
    @test str == join(readlines(txt), "\n")
end

@testset "stopwatch" begin
    t = Time(12, 34, 56, 789)
    str = stopwatch(t)
    txt = joinpath("references", "stopwatch.txt")
    @test str == join(readlines(txt), "\n")
end

@testset "setup_timer" begin
    @test setup_timer(hour = 1) == Time(1, 0, 0)
    @test setup_timer(minute = 2) == Time(0, 2, 0)
    @test setup_timer(second = 3) == Time(0, 0, 3)
    @test setup_timer(hour = 1, minute = 2, second = 3) == Time(1, 2, 3)
end

@testset "preference" begin
    local_prefs_toml = joinpath(dirname(dirname(pathof(TerminalClock))), "LocalPreferences.toml")
    rm(local_prefs_toml; force=true)
    with_temp_depot() do
        project_dir = joinpath(dirname(@__DIR__,))

        # test for set_dials
        activate_and_run(project_dir, """
            using Pkg; Pkg.instantiate()
            using TerminalClock
            unicodebox = joinpath(dirname(pathof(TerminalClock)), "dials", "UnicodeBox.toml")
            TerminalClock.set_dials(unicodebox)
        """)
        prefs = local_prefs_toml |> TOML.parsefile
        @test haskey(prefs, "TerminalClock")
        @test basename(prefs["TerminalClock"]["tomlfile"]) == "UnicodeBox.toml"

        activate_and_run(project_dir, """
            using Test
            using TerminalClock, Dates
            dt = DateTime(2021, 11, 15, 12, 34, 56, 7)
            str = clock(dt)
            txt = joinpath("references", "UnicodeBox", "clock.txt")
            @test str == join(readlines(txt), "\n")

            t = Time(12, 34, 56, 789)
            str = stopwatch(t)
            txt = joinpath("references", "UnicodeBox", "stopwatch.txt")
            @test str == join(readlines(txt), "\n")
        """)

        # test for clear_dials
        activate_and_run(project_dir, """
            using TerminalClock
            TerminalClock.clear_dials()
        """)

        activate_and_run(project_dir, """
            using Test
            using TerminalClock, Dates
            dt = DateTime(2021, 11, 15, 12, 34, 56, 7)
            str = clock(dt)
            txt = joinpath("references", "ASCII", "clock.txt")
            @test str == join(readlines(txt), "\n")

            t = Time(12, 34, 56, 789)
            str = stopwatch(t)
            txt = joinpath("references", "ASCII", "stopwatch.txt")
            @test str == join(readlines(txt), "\n")
        """)
    end # with_temp_depot
end