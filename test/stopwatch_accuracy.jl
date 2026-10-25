# Opt-in check: julia --project test/stopwatch_accuracy.jl
using TerminalClock
using Dates
using Test

samples = Tuple{Float64,Float64}[]
origin = Ref(UInt64(0))
function measured_now()
    tick = time_ns()
    origin[] == 0 && (origin[] = tick)
    return tick
end
TerminalClock._stopwatch(0.1;
    now_ns=measured_now,
    render=t -> begin
        # Exercise the actual dial formatter and measure when the frame is ready.
        str = stopwatch(t)
        actual = (time_ns() - origin[]) / 1e9
        displayed_ms = Dates.value(t) ÷ 1_000_000
        @test str == stopwatch(Time(0) + Millisecond(displayed_ms))
        push!(samples, (actual, displayed_ms / 1000))
        actual >= 60 && throw(InterruptException())
    end,
    clear=_ -> nothing)
errors = [actual - displayed for (actual, displayed) in samples]
println("frames: ", length(samples),
        ", elapsed seconds: ", samples[end][1],
        ", displayed seconds: ", samples[end][2],
        ", maximum frame error (seconds): ", maximum(abs, errors))
@test maximum(abs, errors) < 0.05
