prefsfile = joinpath(first(DEPOT_PATH), "prefs", "TerminalClock")
mkpath(dirname(prefsfile))

toml = get(ENV, "TERMINAL_CLOCK_TOML", "")
if isempty(toml)
    toml = joinpath(@__DIR__, "../src/", "dials/ASCII.toml")
elseif !isabspath(toml)
    error("""Please set using abspath: ENV[\"TERMINAL_CLOCK_TOML"]=abspath("$toml")""")
end

# taken from IJulia/deps/build.jl
function write_if_changed(filename, contents)
    if !isfile(filename) || read(filename, String) != contents
        write(filename, contents)
    end
end

deps = """
const TERMINAL_CLOCK_TOML=$(repr(toml))
"""

write_if_changed("deps.jl", deps)
write_if_changed(prefsfile, open(toml))
