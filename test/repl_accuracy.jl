# Opt-in Unix pseudo-terminal tests (not part of Pkg.test()):
# julia --project test/repl_accuracy.jl stopwatch 60
# julia --project test/repl_accuracy.jl countdown 600
using TerminalClock
using Dates
using TOML
using Test

function open_pseudoterminal()
    Sys.isunix() || error("This optional PTY test requires Linux or macOS.")
    master_fd, slave_fd = Ref{Cint}(), Ref{Cint}()
    status = ccall(:openpty, Cint,
        (Ref{Cint}, Ref{Cint}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
        master_fd, slave_fd, C_NULL, C_NULL, C_NULL)
    status == 0 || error("openpty failed: ", Base.Libc.errno())
    return Base.TTY(RawFD(master_fd[])), Base.TTY(RawFD(slave_fd[]))
end

function digit_maps()
    dials = TOML.parsefile(TerminalClock.default_tomlfile())
    TerminalClock.toml == dials ||
        error("Run this optional test with the default ASCII dial preferences.")
    names = ["zero", "one", "two", "three", "four", "five",
             "six", "seven", "eight", "nine"]
    return Dict(size => Dict(Tuple(dials[size][name]) => n - 1
        for (n, name) in enumerate(names)) for size in ("Large", "Small"))
end

function decode_frame(rows, mode, maps)
    fields = mode == "stopwatch" ?
        [(0, 9, "Large"), (10, 9, "Large"), (30, 9, "Large"),
         (40, 9, "Large"), (56, 5, "Small"), (62, 5, "Small"),
         (68, 5, "Small")] :
        [(0, 9, "Large"), (10, 9, "Large"), (30, 9, "Large"),
         (40, 9, "Large"), (60, 9, "Large"), (70, 9, "Large")]
    digits = Int[]
    for (offset, width, size) in fields
        glyph = Tuple(String(row[offset+1:offset+width]) for row in rows)
        haskey(maps[size], glyph) || return nothing
        push!(digits, maps[size][glyph])
    end
    if mode == "stopwatch"
        return (10digits[1] + digits[2]) * 60 + 10digits[3] + digits[4] +
               (100digits[5] + 10digits[6] + digits[7]) / 1000
    end
    return (10digits[1] + digits[2]) * 3600 +
           (10digits[3] + digits[4]) * 60 + 10digits[5] + digits[6]
end

function test_repl_accuracy(mode="stopwatch",
                            seconds=mode == "stopwatch" ? 60 : 600)
    mode in ("stopwatch", "countdown") || error("Use stopwatch or countdown.")
    0 < seconds < 3600 || error("Duration must be between 1 and 3599 seconds.")
    maps = digit_maps()
    # Compile the decoder before measuring output receipt.
    example = mode == "stopwatch" ? stopwatch(Time(0)) : clock(Time(0))
    decode_frame(collect.(split(example, '\n')), mode, maps)
    width = mode == "stopwatch" ? 73 : 79
    project = dirname(@__DIR__)
    cmd = `$(Base.julia_cmd()) --project=$project --interactive --banner=no --startup-file=no --history-file=no --color=no`
    cmd = addenv(cmd, "TERM" => "xterm-256color")
    master, slave = open_pseudoterminal()
    process = run(pipeline(cmd; stdin=slave, stdout=slave, stderr=slave); wait=false)
    close(slave)
    timed_out = Ref(false)
    watchdog = Timer(seconds + 120) do _
        timed_out[] = true
        process_running(process) && kill(process)
        close(master)
    end
    samples = Tuple{UInt64,Float64}[]
    rows = Vector{Char}[]
    transcript = IOBuffer()
    try
        # Wait until REPL terminal initialization is complete. Sending input
        # earlier can lose it when the child switches terminal modes on CI.
        write(transcript, readuntil(master, "julia> "))
        command = mode == "stopwatch" ? "stopwatch()" :
                  "countdown(Time(0) + Second($seconds))"
        # Send input to an actual interactive REPL, rather than using julia -e.
        println(master, "using TerminalClock, Dates; $command")
        flush(master)
        while !eof(master)
            line = readline(master)
            received = time_ns()
            position(transcript) < 8192 && println(transcript, line)
            clean = replace(line, r"\x1b\[[0-?]*[ -/]*[@-~]" => "", "\r" => "")
            chars = collect(clean)
            length(chars) == width || continue
            push!(rows, chars)
            length(rows) == 9 || continue
            shown = decode_frame(rows, mode, maps)
            empty!(rows)
            isnothing(shown) && continue
            push!(samples, (received, Float64(shown)))
            if mode == "stopwatch" ? shown >= seconds : shown == 0
                break
            end
        end
    finally
        close(watchdog)
        process_running(process) && kill(process)
        wait(process)
        isopen(master) && close(master)
    end
    @test !timed_out[]
    @test length(samples) > 1
    if timed_out[] || length(samples) <= 1
        println("REPL transcript (first 8 KiB):\n", String(take!(transcript)))
        return nothing
    end
    elapsed = Float64(samples[end][1] - samples[1][1]) / 1e9
    if mode == "countdown"
        @test samples[1][2] == seconds
        @test samples[end][2] == 0
        println("REPL countdown: ", elapsed, " s between first and zero frames; error: ",
                elapsed - seconds, " s; frames: ", length(samples))
        @test abs(elapsed - seconds) < 1
    else
        # Anchor to first received frame: this measures drift and output stalls,
        # and excludes REPL startup/JIT before the first visible frame.
        origin = samples[1][1]
        errors = [Float64(tick - origin) / 1e9 - (shown - samples[1][2])
                  for (tick, shown) in samples]
        ages = [Float64(samples[i][1] - origin) / 1e9 -
                (samples[i-1][2] - samples[1][2]) for i in 2:length(samples)]
        println("REPL stopwatch: ", elapsed, " s; last displayed: ", samples[end][2],
                " s; last drift: ", errors[end], " s; maximum frame drift: ",
                maximum(abs, errors), " s; maximum age before update: ",
                maximum(ages), " s; frames: ", length(samples))
        @test abs(errors[end]) < 0.25
        @test maximum(abs, errors) < 0.25
    end
end

mode = isempty(ARGS) ? "stopwatch" : ARGS[1]
seconds = length(ARGS) > 1 ? parse(Int, ARGS[2]) :
          mode == "stopwatch" ? 60 : 600
@testset "REPL accuracy" begin
    test_repl_accuracy(mode, seconds)
end
