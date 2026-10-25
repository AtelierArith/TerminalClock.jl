```@meta
CurrentModule = TerminalClock
```

# [Custom dials](@id custom-dials)

## Select a bundled font

TerminalClock includes `ASCII.toml`, `ASCII2.toml`, and `UnicodeBox.toml` under
`src/dials`. Select a file in the Julia environment where you use the package:

```julia
using TerminalClock

font = joinpath(dirname(pathof(TerminalClock)), "dials", "UnicodeBox.toml")
TerminalClock.set_dials(font)
```

Restart Julia, activate the same environment, and import TerminalClock again.
The dials are loaded when the module is imported, so an already-running clock
does not change fonts.

To restore the default:

```julia
TerminalClock.clear_dials()
# Restart Julia.
```

Preferences are associated with the active environment. Do not assume a choice
made in one project will apply in another.

## Create your own TOML file

The simplest starting point is a copy of the bundled default:

```julia
using TerminalClock

source = joinpath(dirname(pathof(TerminalClock)), "dials", "ASCII.toml")
cp(source, "MyDials.toml") # Choose a new destination if this file already exists.
TerminalClock.set_dials(abspath("MyDials.toml"))
# Restart Julia after editing the file.
```

Keep the custom file at that path. `set_dials` saves the path, not the contents,
and does not validate the file immediately.

Each dial table needs eleven keys: `zero`, `one`, `two`, `three`, `four`,
`five`, `six`, `seven`, `eight`, `nine`, and `colon`. Every value is an
array of strings, one string per row.

- `[Large]` is required and supplies the clock/countdown digits.
- `[Small]` is optional and supplies the stopwatch's subsecond digits and colon.
  If omitted, it falls back to `[Large]`.
- Use the same number of rows for every glyph in both tables. Concatenation
  truncates to the shortest glyph; it does not pad missing rows.
- Keep consistent visible widths within a table. Avoid tabs, control codes,
  combining characters, or wide characters unless your terminal handles them
  as intended.

Here is a complete, compact three-row font. Save the block as `TinyDials.toml`,
select its absolute path with `set_dials`, and restart Julia:

```toml
[Large]
zero  = [" _ ", "| |", "|_|"]
one   = ["   ", "  |", "  |"]
two   = [" _ ", " _|", "|_ "]
three = [" _ ", " _|", " _|"]
four  = ["   ", "|_|", "  |"]
five  = [" _ ", "|_ ", " _|"]
six   = [" _ ", "|_ ", "|_|"]
seven = [" _ ", "  |", "  |"]
eight = [" _ ", "|_|", "|_|"]
nine  = [" _ ", "|_|", " _|"]
colon = ["   ", " . ", " . "]
```

This omits `[Small]`, so all glyphs use the same height and width.

## [Recovering from a bad preference](@id dial-recovery)

A missing file, malformed TOML, or missing glyph can prevent
`using TerminalClock`. In that case you cannot call `clear_dials()` yet.

Open the active project's `LocalPreferences.toml` and remove the `tomlfile`
entry from its `[TerminalClock]` section, preserving other settings. Restart
Julia and try the import again. If the preference is inherited from another
environment, inspect that environment's preference file as well.

When import still works, use `TerminalClock.clear_dials()` and restart instead
of editing files manually.
