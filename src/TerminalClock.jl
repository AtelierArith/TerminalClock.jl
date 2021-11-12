module TerminalClock
using Dates

export clock

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

function clock()
    H = 9
    while true
        try
            buf = IOBuffer()
            n = Dates.now()
            h = hour(n)
            m = minute(n)
            s = second(n)
            h1, h2 = n2d.(divrem(h, 10))
            m1, m2 = n2d.(divrem(m, 10))
            s1, s2 = n2d.(divrem(s, 10))
            print(buf, hcat(h1, h2, colon, m1, m2, colon, s1, s2).str)
            buf |> take! |> String |> print
            sleep(0.5)
            clean(H)
        catch e
            isa(e, InterruptException) || error(e)
            break
        end
    end
end

end # module
