struct Dial
    str::String
    Dial(str::AbstractString) = new(chomp(str))
end

Base.split(d::Dial, dlm) = split(d.str, dlm)

function Base.hcat(dl::Dial, dr::Dial)
    buf = IOBuffer()
    n = min(length(split(dl, "\n")), length(split(dr, "\n")))
    for (i, (l1, l2)) in enumerate(zip(split(dl, "\n"), split(dr, "\n")))
        pfun = i != n ? println : print
        pfun(buf, l1 * " " * l2)
    end
    buf |> take! |> String |> Dial
end

Base.hcat(ds::Dial...) = reduce(hcat, ds)
