```@meta
CurrentModule = TerminalClock
```

# [Development](@id development)

## Work from a checkout

```sh
git clone https://github.com/AtelierArith/TerminalClock.jl.git
cd TerminalClock.jl
julia --project -e 'using Pkg; Pkg.instantiate()'
```

Keep the default ASCII dial preference when running the reference-output and
REPL tests. If you changed the font, clear the preference and restart Julia first.

## Run the tests

```sh
julia --project -e 'using Pkg; Pkg.test()'
julia +1.10 --project -e 'using Pkg; Pkg.test()'
```

The second command assumes Juliaup and its `1.10` channel are installed.

The normal suite checks glyph rendering, reference frames, preferences across
fresh processes, error handling, and simulated timer behavior. In particular,
the timing tests inject rendering and sleep delays so they can check ten minutes
of countdown behavior quickly.

The same test target includes:

- **Aqua.jl**: package quality checks, including ambiguities, undefined exports,
  dependency compatibility, and piracy checks.
- **JET.jl**: abstract package analysis and representative concrete call analysis.
  Package analysis targets errors reported in TerminalClock itself; concrete
  calls also inspect their callees. Generated Configurations constructors can
  intentionally reject invalid input in `Base.convert`.
- Invalid stopwatch intervals are tested at runtime. JET 0.12's call analysis
  ignores explicit throws for that interval-validation path; JET 0.9 uses its
  corresponding supported configuration.

JET depends on compiler internals. The test environment resolves a compatible
JET version for Julia 1.10 and the latest stable Julia; it does not silently
skip verification on those versions.

## Run REPL and accuracy tests

The optional checks are described under [Timer accuracy](@ref timer-accuracy).
A quick Unix REPL check is:

```sh
julia --project test/repl_accuracy.jl stopwatch 2
julia --project test/repl_accuracy.jl countdown 2
```

The REPL harness uses POSIX pseudo-terminals and supports Linux and macOS.
Windows is covered by normal unit, Aqua, and JET tests.

## Build this documentation

The documentation has its own environment. From the repository root:

```sh
julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

Open `docs/build/index.html` in a browser. Local builds use file-friendly links
and do not deploy. The generated `docs/Manifest.toml` and `docs/build/` are not
committed.

The build runs Documenter doctests, checks cross-references, and requires
documentation for exported functions. Live `clock()` and `stopwatch()` examples
are plain code blocks to avoid starting endless tasks during the build;
single-frame examples can run safely.

## CI and documentation deployment

The workflow follows the structure of the
[PkgTemplates CI template](https://github.com/JuliaCI/PkgTemplates.jl/blob/9bdff42b38425af259300c8a60dda0130136c29b/templates/github/workflows/CI.yml)
and its
[Documenter template](https://github.com/JuliaCI/PkgTemplates.jl/blob/9bdff42b38425af259300c8a60dda0130136c29b/templates/docs/make.jlt),
with current checkout/cache action releases and this package's test matrix.

| Job | Coverage |
|:--|:--|
| Test matrix | Julia `1.10` and `1` on Ubuntu, macOS, and Windows, using each runner's native architecture. |
| Unix REPL checks | Two-second stopwatch/countdown checks on Linux and macOS. |
| Documentation | Documenter build, documentation examples, and explicit source doctests on Julia `1`. |

Pushes to `main`, tags, pull requests, and manual dispatch trigger CI.
Pull requests build documentation but do not publish it. Documenter publishes
`main` documentation to `dev/` on the `gh-pages` branch; releases can receive
versioned documentation.

Deployment follows Documenter's SSH deploy-key setup. The repository must have
a write-enabled Deploy key whose private half is stored as the base64-encoded
`DOCUMENTER_KEY` Actions secret. The private key must never be printed or
committed. A secret without its matching repository Deploy key causes
`Permission denied (publickey)` on main even when PR documentation builds pass.

The documentation job has cache, content, and status permissions. GitHub Pages
serves the `gh-pages` branch. See Documenter's
[hosting guide](https://documenter.juliadocs.org/stable/man/hosting/) for the
authentication and hosting requirements.
