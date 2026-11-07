```@meta
CurrentModule = TerminalClock
```

# [Custom dials](@id custom-dials)

## Select a bundled font

TerminalClock includes `ASCII.toml`, `ASCII2.toml`, `UnicodeBox.toml`,
`Keycap.toml`, and `Text.toml` under `src/dials`. Select a file in the Julia environment where you use the package:

```julia
using TerminalClock

font = joinpath(dirname(pathof(TerminalClock)), "dials", "UnicodeBox.toml")
TerminalClock.set_dials(font)
```

Restart Julia, activate the same environment, and import TerminalClock again.
The dials are loaded when the module is imported, so an already-running clock
does not change fonts.

The live displays choose among the loaded dials by terminal size on every
refresh: the first candidate dial is used when it fits, then `Keycap`, then
`Text`, so a small pane switches to a smaller dial automatically. A frame fits
when its height is at most the terminal's rows minus 1 and its width is at most
the terminal's columns. The last candidate is used when nothing fits.

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
- Rows of a glyph are padded on the right with spaces when the file is loaded,
  so every glyph in a table gets a consistent visible width. Avoid tabs,
  control codes, or combining characters. A keycap emoji such as `"1️⃣"` is
  treated as width 2.
- The optional `separator` key (a string) is placed between glyphs. If omitted
  it is a single space; `separator = ""` packs glyphs together.
- A one-line dial is written with one-element arrays. This is an excerpt of
  `Text.toml`:

  ```toml
  [Large]
  separator = ""
  zero = ["0"]
  one = ["1"]
  # ... two to nine ...
  colon = [":"]
  ```

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

The `separator` of `[Small]` is ignored: the `[Large]` separator joins the
whole stopwatch frame, including the small millisecond glyphs.

## Registering several candidates

Pass a vector to `set_dials` to register several dial files, then restart
Julia:

```julia
TerminalClock.set_dials(["/path/to/Big.toml", "/path/to/Medium.toml"])
```

`set_dials` with a path and `set_dials` with a vector replace each other: the
most recent `set_dials` call wins, and the other saved preference is removed.

Candidates are ordered: the registered files in the order given, then the
bundled `Keycap` and `Text` dials. With no registered files, the order is the
`tomlfile` preference (or the bundled ASCII dials), then `Keycap`, then `Text`.
A dial fits when its frame's height is at most the terminal's rows minus 1 and
its width is at most the terminal's columns. The first candidate that fits is used, with
no sorting by size; if none fits, the last one (`Text`) is used.

Single-frame calls such as `clock(Time(12, 34, 56))` always use the first
candidate.

## [Recovering from a bad preference](@id dial-recovery)

A missing file, malformed TOML, or missing glyph can prevent
`using TerminalClock`. In that case you cannot call `clear_dials()` yet.

Open the active project's `LocalPreferences.toml` and remove the `tomlfile`
and `tomlfiles` entries from its `[TerminalClock]` section, preserving other settings. Restart
Julia and try the import again. If the preference is inherited from another
environment, inspect that environment's preference file as well.

When import still works, use `TerminalClock.clear_dials()` and restart instead
of editing files manually.
