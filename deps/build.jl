prefsfile = joinpath(first(DEPOT_PATH), "prefs", "TerminalClock")
mkpath(dirname(prefsfile))

toml = get(ENV, "JULIA_TERMINALCLOCK_PREF", "")
if !isfile(toml)
    toml = joinpath(@__DIR__, "../src/", "dials/ASCII.toml")
end

# taken from IJulia/deps/build.jl
function write_if_changed(filename, contents)
    if !isfile(filename) || read(filename, String) != contents
        write(filename, contents)
    end
end

deps = """
const JULIA_TERMINALCLOCK_PREF=$(repr(toml))
"""

write_if_changed("deps.jl", deps)
write_if_changed(prefsfile, open(toml))
