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

using TerminalClock: framesize, select_font, FONTS, clock_frame

@testset "framesize" begin
    @test framesize("12:34:56") == (1, 8)
    @test framesize("ab\nabcd") == (2, 4)
    @test framesize(clock(Time(12, 34, 56))) == (9, 79)  # measured for ASCII
end

@testset "default candidates" begin
    @test length(FONTS) == 3
    @test clock_frame(FONTS[end], Time(1, 2, 3)) == "01:02:03"
    @test clock_frame(FONTS[2], Time(1, 2, 3)) == "0️⃣1️⃣:0️⃣2️⃣:0️⃣3️⃣"
end

@testset "select_font" begin
    f = font -> clock_frame(font, Time(12, 34, 56))
    big_rows, big_cols = framesize(f(FONTS[1]))
    @test select_font(FONTS, f, (big_rows + 1, big_cols)) === FONTS[1]
    @test select_font(FONTS, f, (big_rows, big_cols)) === FONTS[2]
    @test select_font(FONTS, f, (40, 14)) === FONTS[2]
    @test select_font(FONTS, f, (40, 13)) === FONTS[3]
end

@testset "select_font falls back to last" begin
    f = font -> clock_frame(font, Time(12, 34, 56))
    @test select_font(FONTS, f, (1, 4)) === FONTS[end]
end

@testset "select_font respects order" begin
    f = font -> clock_frame(font, Time(12, 34, 56))
    fonts = [FONTS[3], FONTS[1]]
    @test select_font(fonts, f, (100, 300)) === FONTS[3]
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

        # test for multiple candidates
        activate_and_run(
            project_dir,
            """
    using TerminalClock
    dir = joinpath(dirname(pathof(TerminalClock)), "dials")
    TerminalClock.set_dials([joinpath(dir, "UnicodeBox.toml"), joinpath(dir, "ASCII2.toml")])
""",
        )
        prefs = local_prefs_toml |> TOML.parsefile
        @test basename.(prefs["TerminalClock"]["tomlfiles"]) ==
              ["UnicodeBox.toml", "ASCII2.toml"]

        activate_and_run(
            project_dir,
            """
    using Test
    using TerminalClock, Dates
    @test length(TerminalClock.FONTS) == 4
    dt = DateTime(2021, 11, 15, 12, 34, 56, 7)
    txt = joinpath("references", "UnicodeBox", "clock.txt")
    @test clock(dt) == join(readlines(txt), "\n")
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
    @test length(TerminalClock.FONTS) == 3
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
    prefs = isfile(local_prefs_toml) ? TOML.parsefile(local_prefs_toml) : Dict()
    @test !haskey(get(prefs, "TerminalClock", Dict()), "tomlfiles")
    @test !haskey(get(prefs, "TerminalClock", Dict()), "tomlfile")
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
            clear=() -> nothing)
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
        clear=() -> nothing)
    @test first(shown) == Time(0)
    @test last(shown) == Time(0, 1)
    @test shown[2] == Time(0, 0, 0, 100)
    for duration in (0.0, -0.1, Inf, NaN)
        @test_throws ArgumentError stopwatch(duration)
    end
end

using TerminalClock: _displaywidth, Dial, Font, load_font, clock_frame, stopwatch_frame

using TerminalClock: FONTS

@testset "live display switches dials by terminal size" begin
    sizes = [(40, 200), (3, 40), (2, 8)]   # large / keycap (width 14) / text
    calls = Ref(0)
    ticks = Ref(UInt64(0))
    io = IOBuffer()
    TerminalClock._countdown(Time(0, 0, 2); io,
        now_ns=() -> ticks[],
        wait=seconds -> (ticks[] += round(UInt64, seconds * 1e9)),
        termsize=() -> sizes[(calls[] += 1)])
    out = String(take!(io))
    frames = split(out, TerminalClock.CLEAR_SCREEN; keepempty=false)
    @test startswith(out, TerminalClock.CLEAR_SCREEN)
    @test length(frames) == 3
    @test frames[1] == clock(Time(0, 0, 2)) * "\n"
    @test frames[2] == clock_frame(FONTS[2], Time(0, 0, 1)) * "\n"
    @test frames[3] == "00:00:00\n"
end

@testset "stopwatch live display uses stopwatch frames" begin
    io = IOBuffer()
    n = Ref(0)
    TerminalClock._stopwatch(0.1; io,
        now_ns=() -> UInt64(0), wait=_ -> nothing,
        termsize=() -> ((n[] += 1) > 1 && throw(InterruptException()); (2, 20)))
    # The first frame is keycap (width 16 <= 20). On the second pass termsize
    # throws during render, after the screen was cleared.
    @test String(take!(io)) == TerminalClock.CLEAR_SCREEN *
          stopwatch_frame(FONTS[2], Time(0)) * "\n" * TerminalClock.CLEAR_SCREEN
end

@testset "clock live display leaves the last frame" begin
    io = IOBuffer()
    n = Ref(0)
    TerminalClock._clock(; io, now=() -> DateTime(2026, 1, 1, 12, 34, 56),
        wait=_ -> (n[] += 1) == 2 && throw(InterruptException()),
        termsize=() -> (2, 10))   # keycap (width 14) does not fit, so text
    @test String(take!(io)) == repeat(TerminalClock.CLEAR_SCREEN * "12:34:56\n", 2)
end


@testset "displaywidth" begin
    @test _displaywidth("12:34") == 5
    @test _displaywidth("1️⃣") == 2
    @test _displaywidth("1️⃣2️⃣:") == 5
    @test _displaywidth("🟥⬛") == 4
    @test _displaywidth("█▒░") == 3
end

@testset "Dial pads rows to equal width" begin
    @test Dial(["abc", "a"]).str == "abc\na  "
    @test Dial(["1️⃣", "x"]).str == "1️⃣\nx "
end

const DIGIT_KEYS = ["zero", "one", "two", "three", "four",
                    "five", "six", "seven", "eight", "nine"]
function tiny_text_toml(sep)
    large = Dict{String,Any}(k => [string(n)] for (n, k) in zip(0:9, DIGIT_KEYS))
    large["colon"] = [":"]
    sep === nothing || (large["separator"] = sep)
    return Dict{String,Any}("Large" => large)
end

@testset "separator defaults to a space" begin
    font = Font(tiny_text_toml(nothing))      # no separator
    @test clock_frame(font, Time(12, 34, 56)) == "1 2 : 3 4 : 5 6"
end

@testset "separator joins glyphs" begin
    font = Font(tiny_text_toml(""))
    @test clock_frame(font, Time(12, 34, 56)) == "12:34:56"
    @test stopwatch_frame(font, Time(1, 2, 3, 456)) == "02:03:456"
end

@testset "stopwatch_frame uses the Large separator" begin
    toml = tiny_text_toml("")
    toml["Small"] = merge(copy(toml["Large"]), Dict("separator" => "_", "colon" => ["."]))
    @test stopwatch_frame(Font(toml), Time(0, 2, 3, 456)) == "02:03.456"
end

@testset "load_font reads a TOML file" begin
    font = load_font(joinpath(pkgdir(TerminalClock), "src", "dials", "ASCII.toml"))
    @test font isa Font
    @test clock_frame(font, Time(12, 34, 56)) == clock(Time(12, 34, 56))
end

dialpath(name) = joinpath(dirname(pathof(TerminalClock)), "dials", name)

@testset "bundled one-line dials" begin
    text = load_font(dialpath("Text.toml"))
    @test clock_frame(text, Time(12, 34, 56)) == "12:34:56"
    @test stopwatch_frame(text, Time(12, 34, 56, 789)) == "34:56:789"
    keycap = load_font(dialpath("Keycap.toml"))
    k(n) = "$(n)️⃣"
    @test clock_frame(keycap, Time(12, 34, 56)) == k(1)*k(2)*":"*k(3)*k(4)*":"*k(5)*k(6)
end

@testset "bundled dials have equal row widths" begin
    for file in readdir(joinpath(dirname(pathof(TerminalClock)), "dials"))
        toml = TOML.parsefile(dialpath(file))
        for (table, glyphs) in toml, (key, rows) in glyphs
            key == "separator" && continue
            @test length(unique(_displaywidth.(rows))) == 1
        end
    end
end

@testset "ASCII2 references" begin
    ascii2 = load_font(dialpath("ASCII2.toml"))
    @test clock_frame(ascii2, Time(12, 34, 56)) ==
          join(readlines(joinpath(@__DIR__, "references", "ASCII2", "clock.txt")), "\n")
    @test stopwatch_frame(ascii2, Time(12, 34, 56, 789)) ==
          join(readlines(joinpath(@__DIR__, "references", "ASCII2", "stopwatch.txt")), "\n")
end
