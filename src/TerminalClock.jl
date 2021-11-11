module TerminalClock
using Dates

export clock

function Base.hcat(dl::AbstractString, dr::AbstractString)
    buf = IOBuffer()
    for (l1, l2) in zip(split(dl, "\n"), split(dr, "\n"))
        println(buf, l1 * " " * l2)
    end
    # adjust output
    print(buf, "\x1b[2K") # clear line
    print(buf, "\x1b[999D\x1b[$(1)A") # rollback
    buf |> take! |> String
end

Base.hcat(ds::AbstractString...) = reduce(hcat, ds)

function clean(H)
    buf = IOBuffer()
    for i in 1:H
        print(buf, "\x1b[2K") # clear line
        print(buf, "\x1b[999D\x1b[$(1)A") # rollback
    end
    print(buf |> take! |> String)
end

include("digits.jl")

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
            print(buf, hcat(h1, h2, colon, m1, m2, colon, s1, s2))
            # print(buf, hcat(d, d, colon, d, d))
            # print(buf, "\x1b[999D\x1b[$(H)A") #rollback H-times
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
