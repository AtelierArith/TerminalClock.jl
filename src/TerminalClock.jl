module TerminalClock
using Dates

export displayclock

include("types.jl")
include("dials.jl")

function clean(H)
    buf = IOBuffer()
    for i in 1:H
        print(buf, "\x1b[2K") # clear line
        print(buf, "\x1b[999D\x1b[$(1)A") # rollback
    end
    print(buf |> take! |> String)
end

function createclock(dt=Dates.now())
    buf = IOBuffer()
    h = hour(dt)
    m = minute(dt)
    s = second(dt)
    h1, h2 = n2d.(divrem(h, 10))
    m1, m2 = n2d.(divrem(m, 10))
    s1, s2 = n2d.(divrem(s, 10))
    str = hcat(h1, h2, colon, m1, m2, colon, s1, s2).str
    print(buf, str)
    return buf |> take! |> String
end

function displayclock()
    while true
        try
            str = createclock()
            print(str)
            sleep(0.5)
            H = length(split(str, "\n"))-1
            clean(H)
        catch e
            isa(e, InterruptException) || error(e)
            break
        end
    end
end

end # module
