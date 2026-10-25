using Aqua
using JET

@testset "Aqua" begin
    Aqua.test_all(TerminalClock)
end

@testset "JET" begin
    JET.test_package(TerminalClock; target_defined_modules=true)
    JET.@test_call clock(DateTime(2026, 1, 1, 12, 34, 56))
    JET.@test_call stopwatch(Time(0, 12, 34, 567))
    JET.@test_call setup_timer(minute=10)
    JET.@test_call TerminalClock._countdown(Time(0, 10);
        now_ns=() -> UInt64(0), wait=_ -> nothing,
        render=_ -> nothing, clear=_ -> nothing)
end
