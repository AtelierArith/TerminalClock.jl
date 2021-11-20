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

function n2d(dials::Dials, n::Int)
    n == 0 && return Dial(getfield(dials, :zero))
    n == 1 && return Dial(getfield(dials, :one))
    n == 2 && return Dial(getfield(dials, :two))
    n == 3 && return Dial(getfield(dials, :three))
    n == 4 && return Dial(getfield(dials, :four))
    n == 5 && return Dial(getfield(dials, :five))
    n == 6 && return Dial(getfield(dials, :six))
    n == 7 && return Dial(getfield(dials, :seven))
    n == 8 && return Dial(getfield(dials, :eight))
    n == 9 && return Dial(getfield(dials, :nine))
    DomainError("n should satisfy 0≤ n ≤9, actual $n")
end

colon(dial::Dials) = Dial(getfield(dial, :colon))

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
