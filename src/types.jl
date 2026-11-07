# Terminal cell width of `s`. A keycap grapheme (contains U+20E3) occupies two cells.
function _displaywidth(s::AbstractString)
    w = 0
    for g in Base.Unicode.graphemes(s)
        w += '\u20e3' in g ? 2 : textwidth(g)
    end
    return w
end

struct Dial
    str::String
    Dial(str::AbstractString) = new(chomp(str))
    function Dial(rows::Vector{String})
        width = maximum(_displaywidth, rows; init=0)
        padded = [r * " "^(width - _displaywidth(r)) for r in rows]
        return new(join(padded, "\n"))
    end
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
    separator::String = " "
end

struct Font
    large::Dials
    small::Dials
end

function Font(toml::AbstractDict)
    large = toml["Large"]
    return Font(from_dict(Dials, large), from_dict(Dials, get(toml, "Small", large)))
end

Base.split(d::Dial, dlm) = split(d.str, dlm)

function _join(sep::AbstractString, dl::Dial, dr::Dial)
    ls = split(dl, "\n")
    rs = split(dr, "\n")
    return Dial(join((l * sep * r for (l, r) in zip(ls, rs)), "\n"))
end

_join(sep::AbstractString, d::Dial) = d
_join(sep::AbstractString, d::Dial, ds::Dial...) =
    foldl((a, b) -> _join(sep, a, b), ds; init=d)

Base.hcat(d::Dial) = d
Base.hcat(d::Dial, ds::Dial...) = _join(" ", d, ds...)
