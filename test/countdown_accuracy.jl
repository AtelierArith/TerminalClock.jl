# Opt-in real-time check: julia --project test/countdown_accuracy.jl
# Output goes to the null device; this measures scheduling and rendering overhead,
# not latency introduced by a particular terminal emulator.
using TerminalClock
using Dates
using Test

redirect_stdout(devnull) do
    countdown(Time(0)) # compile before measuring
end
elapsed = redirect_stdout(devnull) do
    start = time_ns()
    countdown(minute=10)
    (time_ns() - start) / 1e9
end
println("10-minute countdown elapsed: ", elapsed, " seconds")
@test 600 <= elapsed < 601
