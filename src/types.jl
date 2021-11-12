struct Dial
    str::String
end

Base.split(d::Dial, dlm) = split(d.str, dlm)
Base.show(io::IO, mime, d::Dial) = show(io, mime, d.str)

function Base.hcat(dl::Dial, dr::Dial)
    buf = IOBuffer()
    for (l1, l2) in zip(split(dl, "\n"), split(dr, "\n"))
        println(buf, l1 * " " * l2)
    end
    # adjust output
    print(buf, "\x1b[2K") # clear line
    print(buf, "\x1b[999D\x1b[$(1)A") # rollback
    buf |> take! |> String |> Dial
end

Base.hcat(ds::Dial...) = reduce(hcat, ds)
