struct Dial
    str::String
    Dial(str::AbstractString) = new(chomp(str))
    Dial(str::Vector{String}) = new(join(str, "\n"))
end

abstract type FontSize end
struct Small <: FontSize end
struct Large <: FontSize end

@option "dials" struct Dials
    one::Vector{String}
    two::Vector{String}
    three::Vector{String}
    four::Vector{String}
    five::Vector{String}
    six::Vector{String}
    seven::Vector{String}
    eight::Vector{String}
    nine::Vector{String}
    zero::Vector{String}
    colon::Vector{String}
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
