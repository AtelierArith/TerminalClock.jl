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
function activate_and_run(project_dir::String, code::String; env::Dict=Dict())
    mktempdir() do dir
        open(joinpath(dir, "test_code.jl"), "w") do io
            write(io, code)
        end

        out = Pipe()
        cmd =
            setenv(`$(Base.julia_cmd()) --project=$(project_dir) $(dir)/test_code.jl`,
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
    for n in 0:9
        @test length(split(n2d(n).str, "\n")) == 9
        @test length(split(n2d(n), "\n")) == 9
    end
    @test length(split(COLON_LARGE, "\n")) == 9
end

@testset "hcat" begin
    @test hcat(n2d(1)).str == n2d(1).str
    d1 = hcat(n2d(1), n2d(2))
    @test length(split(d1, "\n")) == 9

    d2 = hcat(n2d(1), n2d(2), COLON_LARGE, n2d(3), n2d(4))
    @test length(split(d2, "\n")) == 9
end

@testset "clock" begin
    dt = DateTime(2021, 11, 15, 12, 34, 56, 7)
    str = clock(dt)
    txt = joinpath("references", "ASCII", "clock.txt")
    @test str == join(readlines(txt), "\n")
end

@testset "stopwatch" begin
    t = Time(12, 34, 56, 789)
    str = stopwatch(t)
    txt = joinpath("references", "ASCII", "stopwatch.txt")
    @test str == join(readlines(txt), "\n")
end

@testset "setup_timer" begin
    @test setup_timer(hour=1) == Time(1, 0, 0)
    @test setup_timer(minute=2) == Time(0, 2, 0)
    @test setup_timer(second=3) == Time(0, 0, 3)
    @test setup_timer(hour=1, minute=2, second=3) == Time(1, 2, 3)
end

@testset "preference" begin
    local_prefs_toml =
        joinpath(dirname(dirname(pathof(TerminalClock))), "LocalPreferences.toml")
    rm(local_prefs_toml; force=true)
    with_temp_depot() do
        project_dir = joinpath(dirname(@__DIR__))

        # test for set_dials
        activate_and_run(
            project_dir,
            """
    using Pkg; Pkg.instantiate()
    using TerminalClock
    unicodebox = joinpath(dirname(pathof(TerminalClock)), "dials", "UnicodeBox.toml")
    TerminalClock.set_dials(unicodebox)
""",
        )
        prefs = local_prefs_toml |> TOML.parsefile
        @test haskey(prefs, "TerminalClock")
        @test basename(prefs["TerminalClock"]["tomlfile"]) == "UnicodeBox.toml"

        activate_and_run(
            project_dir,
            """
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
""",
        )

        # test for clear_dials
        activate_and_run(
            project_dir,
            """
    using TerminalClock
    TerminalClock.clear_dials()
""",
        )

        activate_and_run(
            project_dir,
            """
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
""",
        )
    end # with_temp_depot
end

@testset "countdown timing" begin
    function simulate(t; render_ns=0, oversleep_ns=0)
        ticks = Ref(UInt64(0))
        frames = Tuple{Float64,Time}[]
        waits = Float64[]
        TerminalClock._countdown(t;
            now_ns=() -> ticks[],
            wait=seconds -> begin
                push!(waits, seconds)
                ticks[] += round(UInt64, seconds * 1e9) + oversleep_ns
            end,
            render=shown -> begin
                push!(frames, (ticks[] / 1e9, shown))
                ticks[] += render_ns
            end,
            clear=_ -> nothing)
        return frames, waits, ticks[] / 1e9
    end

    frames, waits, elapsed = simulate(Time(0, 10); render_ns=20_000_000,
                                     oversleep_ns=5_000_000)
    @test frames[1] == (0.0, Time(0, 10))
    @test frames[end][2] == Time(0)
    @test 600 <= frames[end][1] <= 600.01
    @test elapsed < 600.1
    @test length(waits) == 600

    frames, waits, elapsed = simulate(Time(0))
    @test frames == [(0.0, Time(0))]
    @test isempty(waits)
    @test elapsed == 0

    frames, _, elapsed = simulate(Time(0, 0, 4); render_ns=1_500_000_000)
    @test last.(frames) == [Time(0, 0, 4), Time(0, 0, 3), Time(0, 0, 1), Time(0)]
    @test frames[end][1] == 4.5

    frames, _, _ = simulate(Time(0, 0, 0, 500))
    @test first(frames)[2] == Time(0, 0, 1)
    @test last(frames) == (0.5, Time(0))

    @test TerminalClock._countdown(Time(0); render=_ -> throw(InterruptException())) === nothing
    @test_throws ArgumentError TerminalClock._countdown(Time(0);
        render=_ -> throw(ArgumentError("render failed")))
    @test_throws DomainError n2d(-1)
    @test_throws DomainError n2d(10)
end

include("verification.jl")

@testset "stopwatch timing" begin
    @test TerminalClock._elapsed_time(UInt64(86_400_123_000_000)) == Time(0, 0, 0, 123)
    ticks = Ref(UInt64(0))
    shown = Time[]
    TerminalClock._stopwatch(0.1;
        now_ns=() -> ticks[],
        wait=seconds -> (ticks[] += round(UInt64, seconds * 1e9)),
        render=t -> begin
            push!(shown, t)
            ticks[] += 20_000_000 # rendering delay must count as elapsed time
            length(shown) == 601 && throw(InterruptException())
        end,
        clear=_ -> nothing)
    @test first(shown) == Time(0)
    @test last(shown) == Time(0, 1)
    @test shown[2] == Time(0, 0, 0, 100)
    for duration in (0.0, -0.1, Inf, NaN)
        @test_throws ArgumentError stopwatch(duration)
    end
end
