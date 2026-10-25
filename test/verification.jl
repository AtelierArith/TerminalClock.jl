using Aqua
using JET

@testset "Aqua" begin
    Aqua.test_all(TerminalClock)
end

@testset "JET" begin
    # Restrict abstract signature analysis to errors in this package. Generated
    # Configurations constructors accept Any and can intentionally reject invalid
    # inputs in Base.convert; concrete public calls below retain full analysis.
    JET.test_package(TerminalClock; target_modules=(TerminalClock,))
    JET.@test_call TerminalClock.n2d(5)
    JET.@test_call hcat(TerminalClock.n2d(1), TerminalClock.n2d(2))
    JET.@test_call clock(DateTime(2026, 1, 1, 12, 34, 56))
    JET.@test_call stopwatch(Time(0, 12, 34, 567))
    JET.@test_call setup_timer(minute=10)
    # JET analyzes Float64 rather than its value; interval validation can throw
    # for NaN/nonpositive values, covered separately by runtime tests.
    verify_stopwatch = interval -> TerminalClock._stopwatch(interval;
        now_ns=() -> UInt64(0), wait=_ -> nothing,
        render=_ -> nothing, clear=_ -> nothing)
    # JET 0.9 on Julia 1.10 predates the ignore_throws option.
    options = Base.pkgversion(JET) >= v"0.12" ? (; ignore_throws=true) : (;)
    JET.test_call(verify_stopwatch, (Float64,); options...)
    JET.@test_call TerminalClock._countdown(Time(0, 10);
        now_ns=() -> UInt64(0), wait=_ -> nothing,
        render=_ -> nothing, clear=_ -> nothing)
end
