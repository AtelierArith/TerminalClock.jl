# Adaptive Dials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ライブ表示（`clock()` / `countdown` / `stopwatch`）が、描画のたびにターミナルの大きさに収まる最大の文字盤を自動で選ぶようにする。Keycap と Text の 1 行の文字盤を同梱し、自作の文字盤を複数登録できるようにする。

**Architecture:** 文字盤ファイル 1 つを `Font`（`[Large]` と `[Small]` の組）として読み込み、候補を `Vector{Font}` として import 時に `const FONTS` に用意する。フレームの生成は `clock_frame(font, t)` / `stopwatch_frame(font, t)` という純粋関数にし、選択は `select_font(fonts, frame, termsize)` という純粋関数にする。ライブ表示のループは描画のたびに、画面全体の消去 → 文字盤の選択 → 描画を行う。

**Tech Stack:** Julia 1.10+、Configurations.jl（`@option`）、Preferences.jl、TOML、Test / Aqua / JET。

**Spec:** `docs/superpowers/specs/2026-11-07-adaptive-dials-design.md`

## Global Constraints

- 既存の TOML 文字盤（`[Large]` 必須、`[Small]` 任意、`separator` なし）がそのまま読めること。
- `set_dials(::AbstractString)` は今まで通り preference `tomlfile` に保存し、意味を変えない。
- `clock(::Time)` / `clock(::DateTime)` / `stopwatch(::Time)` は候補の先頭の文字盤を使い、同梱 ASCII と UnicodeBox の戻り値は今と 1 文字も変えない（既存の `test/references/` がそのまま通ること）。
- 秒は省略しない。`clock` / `countdown` は `HH:MM:SS`、`stopwatch` は `MM:SS:mmm`。
- `separator` の既定値は `" "`。
- keycap（`U+20E3` を含む書記素）は表示幅 2 として数える。
- 収まる条件: `rows ≤ termrows - 1` かつ `cols ≤ termcols`。
- 画面全体の消去は `"\e[H\e[2J"`。終了時（Ctrl+C、countdown 終了）は最後のフレームを残す。
- countdown / stopwatch の時間計測（単調時計、描画時間の差し引き）を変えない。既存の timing テストが通ること。
- テストは t_wada 流の TDD（Red → Green → Refactor）。テストの実行は `julia --project -e 'using Pkg; Pkg.test()'`。

## Review Focus

1. **`separator` を書いていない既存・自作の TOML** — 今まで通り空白 1 つで並ぶこと。→ Task 1 のテスト `separator defaults to a space`。
2. **幅 2 の普通の絵文字（🟥 など）を使った自作のドット絵文字盤** — `textwidth` 通り 2 として数え、幅の計算や選択が正しく動くこと。→ Task 1 のテスト `displaywidth` に 🟥 を含める。
3. **Text より狭いペイン（8 桁未満、1 行しかない）** — 例外を出さず、最後の候補（Text）を表示すること。→ Task 3 のテスト `select_font falls back to last`。
4. **登録した自作の文字盤が Keycap より小さい** — 登録順を優先し、並べ替えないこと（収まる最初の候補を選ぶ）。→ Task 3 のテスト `select_font respects order`。
5. **stopwatch で `[Small]` が `[Large]` と別の高さ・別の separator を持つ文字盤** — `[Large]` の separator で全体をつなぐ。高さは既存通り短い方に切り詰められる。→ Task 1 のテスト `stopwatch_frame uses the Large separator`。

---

### Task 1: `separator`、表示幅、幅そろえ、フレーム生成関数

**Files:**
- Modify: `src/types.jl`（`Dial`、`Dials`、`hcat`）
- Modify: `src/TerminalClock.jl`（`clock(::Time)`、`stopwatch(::Time)`、`n2d`）
- Test: `test/runtests.jl`

**Interfaces:**
- Produces:
  - `_displaywidth(s::AbstractString)::Int` — 書記素ごとの幅の合計。`'⃣'` を含む書記素は 2、それ以外は `textwidth(g)`。
  - `Dial(rows::Vector{String})` — 各行を `_displaywidth` の最大値まで右側を空白で埋めてから `"\n"` でつなぐ。
  - `Dials` に `separator::String = " "` を追加（Configurations の既定値）。
  - `struct Font; large::Dials; small::Dials; end`
  - `Font(toml::AbstractDict)::Font` — `toml["Large"]` と `get(toml, "Small", toml["Large"])` から作る。
  - `load_font(path::AbstractString)::Font`
  - `_join(sep::AbstractString, d::Dial, ds::Dial...)::Dial` — 行ごとに `sep` でつなぐ。行数は最短に切り詰める（既存の `hcat` と同じ）。`Base.hcat(::Dial...)` は `_join(" ", ...)` を呼ぶだけにする。
  - `n2d(dials::Dials, n::Int)::Dial`（既存のまま）と `colon(dials::Dials)::Dial`（既存のまま）。
  - `clock_frame(font::Font, t::Time)::String` — `HH:MM:SS`、`font.large.separator` でつなぐ。
  - `stopwatch_frame(font::Font, t::Time)::String` — `MM:SS` は Large、コロン 2 つ目と `mmm` は Small。全体を `font.large.separator` でつなぐ。
  - `clock(t::Time)` / `stopwatch(t::Time)` は `clock_frame(FONTS[1], t)` / `stopwatch_frame(FONTS[1], t)`。この Task ではまだ `FONTS` がないので、`const FONTS = [Font(toml)]` の仮置きでよい（Task 3 で置き換える）。`DIALS_LARGE` / `DIALS_SMALL` / `COLON_LARGE` / `COLON_SMALL` は `FONTS[1]` から作り、既存のテストの import を壊さない。

- [ ] **Step 1: 失敗するテストを書く**（`test/runtests.jl` に testset を追加）

```julia
using TerminalClock: _displaywidth, Dial, Font, load_font, clock_frame, stopwatch_frame

@testset "displaywidth" begin
    @test _displaywidth("12:34") == 5
    @test _displaywidth("1️⃣") == 2
    @test _displaywidth("1️⃣2️⃣:") == 5
    @test _displaywidth("🟥⬛") == 4
    @test _displaywidth("█▒░") == 3
end

@testset "Dial pads rows to equal width" begin
    @test Dial(["abc", "a"]).str == "abc\na  "
    @test Dial(["1️⃣", "x"]).str == "1️⃣\nx "
end

const DIGIT_KEYS = ["zero", "one", "two", "three", "four",
                    "five", "six", "seven", "eight", "nine"]
function tiny_text_toml(sep)
    large = Dict{String,Any}(k => [string(n)] for (n, k) in zip(0:9, DIGIT_KEYS))
    large["colon"] = [":"]
    sep === nothing || (large["separator"] = sep)
    return Dict{String,Any}("Large" => large)
end

@testset "separator defaults to a space" begin
    font = Font(tiny_text_toml(nothing))      # separator なし
    @test clock_frame(font, Time(12, 34, 56)) == "1 2 : 3 4 : 5 6"
end

@testset "separator joins glyphs" begin
    font = Font(tiny_text_toml(""))
    @test clock_frame(font, Time(12, 34, 56)) == "12:34:56"
    @test stopwatch_frame(font, Time(1, 2, 3, 456)) == "02:03:456"
end

@testset "stopwatch_frame uses the Large separator" begin
    toml = tiny_text_toml("")
    toml["Small"] = merge(copy(toml["Large"]), Dict("separator" => "_", "colon" => ["."]))
    @test stopwatch_frame(Font(toml), Time(0, 2, 3, 456)) == "02:03.456"
end
```

- [ ] **Step 2: テストが失敗することを確かめる**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: FAIL（`_displaywidth` / `Font` / `clock_frame` が未定義で `UndefVarError`）

- [ ] **Step 3: Interfaces に書いた関数と型を実装する**

書記素の分割は `Base.Unicode.graphemes`。`Dials` への `separator` 追加は `separator::String = " "`。

- [ ] **Step 4: すべてのテストが通ることを確かめる**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: PASS（既存の `clock` / `stopwatch` / preference の参照テスト、Aqua、JET を含む）

- [ ] **Step 5: コミット**

```bash
git add src/types.jl src/TerminalClock.jl test/runtests.jl
git commit -m "Add dial separator, display width, and frame functions"
```

---

### Task 2: 同梱の Keycap / Text 文字盤、ASCII2 の修正、ドキュメント（TOML 仕様）

**Files:**
- Create: `src/dials/Keycap.toml`, `src/dials/Text.toml`
- Modify: `src/dials/ASCII2.toml`（`[Small]` `seven` の最後の行を幅 5 に）
- Create: `test/references/ASCII2/clock.txt`, `test/references/ASCII2/stopwatch.txt`
- Modify: `docs/src/dials.md`
- Test: `test/runtests.jl`

**Interfaces:**
- Consumes: `load_font`, `clock_frame`, `stopwatch_frame`, `_displaywidth`（Task 1）
- Produces: 同梱ファイル `Keycap.toml` / `Text.toml`。どちらも `[Large]` と `[Small]` が同じ内容、`separator = ""`、`colon = [":"]`。Keycap の数字 n は `"$(n)️⃣"`（TOML では `"1️⃣"` のようにエスケープで書く）。

- [ ] **Step 1: 失敗するテストを書く**

```julia
dialpath(name) = joinpath(dirname(pathof(TerminalClock)), "dials", name)

@testset "bundled one-line dials" begin
    text = load_font(dialpath("Text.toml"))
    @test clock_frame(text, Time(12, 34, 56)) == "12:34:56"
    @test stopwatch_frame(text, Time(12, 34, 56, 789)) == "34:56:789"
    keycap = load_font(dialpath("Keycap.toml"))
    k(n) = "$(n)️⃣"
    @test clock_frame(keycap, Time(12, 34, 56)) == k(1)*k(2)*":"*k(3)*k(4)*":"*k(5)*k(6)
end

@testset "bundled dials have equal row widths" begin
    for file in readdir(joinpath(dirname(pathof(TerminalClock)), "dials"))
        toml = TOML.parsefile(dialpath(file))
        for (table, glyphs) in toml, (key, rows) in glyphs
            key == "separator" && continue
            @test length(unique(_displaywidth.(rows))) == 1
        end
    end
end

@testset "ASCII2 references" begin
    ascii2 = load_font(dialpath("ASCII2.toml"))
    @test clock_frame(ascii2, Time(12, 34, 56)) ==
          join(readlines(joinpath("references", "ASCII2", "clock.txt")), "\n")
    @test stopwatch_frame(ascii2, Time(12, 34, 56, 789)) ==
          join(readlines(joinpath("references", "ASCII2", "stopwatch.txt")), "\n")
end
```

- [ ] **Step 2: テストが失敗することを確かめる**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: FAIL（Keycap.toml / Text.toml がない。ASCII2 の `[Small]` `seven` で `equal row widths` が失敗。参照ファイルがない）

- [ ] **Step 3: `Keycap.toml` と `Text.toml` を作り、`ASCII2.toml` の `[Small]` `seven` の最後の行 `"    "` を `"     "`（空白 5 つ）に直す**

- [ ] **Step 4: ASCII2 の参照ファイルを生成し、目で確かめる**

Run: `julia --project -e 'using TerminalClock, Dates; f = TerminalClock.load_font(joinpath(dirname(pathof(TerminalClock)), "dials", "ASCII2.toml")); mkpath("test/references/ASCII2"); write("test/references/ASCII2/clock.txt", TerminalClock.clock_frame(f, Time(12,34,56)) * "\n"); write("test/references/ASCII2/stopwatch.txt", TerminalClock.stopwatch_frame(f, Time(12,34,56,789)) * "\n")'`
Expected: 2 つのファイルができる。`cat` で表示し、`12:34:56` と `34:56:789` が崩れずに読めること（stopwatch の `789` の 7 の行がずれていないこと）を確認する。

- [ ] **Step 5: `docs/src/dials.md` を更新する**

追記する内容: 同梱ファイルに `Keycap.toml` と `Text.toml` を加える。`separator` キー（省略時は空白 1 つ、`""` で詰めて表示）。1 行の文字盤は 1 要素の配列で書けること（`Text.toml` の抜粋を例に）。各グリフの行は読み込み時に右側を空白で埋めて幅がそろうこと（「Keep consistent visible widths」の箇条を置き換える）。keycap は幅 2 として扱うこと。

- [ ] **Step 6: すべてのテストが通ることを確かめる**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: PASS

- [ ] **Step 7: コミット**

```bash
git add src/dials test/references/ASCII2 test/runtests.jl docs/src/dials.md
git commit -m "Bundle Keycap and Text dials and fix ASCII2 small seven width"
```

---

### Task 3: 候補の登録（`tomlfiles`）と選択

**Files:**
- Modify: `src/TerminalClock.jl`（`set_dials`、`clear_dials`、`load_dials` → `load_fonts`、`const FONTS`）
- Modify: `docs/src/dials.md`（複数登録と候補の順序、復旧手順に `tomlfiles` を追加）
- Test: `test/runtests.jl`

**Interfaces:**
- Consumes: `Font`, `load_font`, `clock_frame`, `_displaywidth`（Task 1）、同梱 Keycap / Text（Task 2）
- Produces:
  - `set_dials(tomlfiles::AbstractVector{<:AbstractString})` — preference `"tomlfiles"` に `Vector{String}` で保存。
  - `clear_dials()` — `"tomlfile"` と `"tomlfiles"` の両方を `nothing` にする。
  - `load_fonts()::Vector{Font}` — `tomlfiles` が空でなければその順、そうでなければ `[tomlfile または ASCII.toml]`。その後に同梱 `Keycap.toml`、`Text.toml` を続ける。
  - `const FONTS = load_fonts()`（Task 1 の仮置きを置き換える）。
  - `framesize(frame::AbstractString)::Tuple{Int,Int}` — `(行数, 各行の _displaywidth の最大)`。
  - `select_font(fonts::AbstractVector{Font}, frame, termsize::Tuple{Int,Int})::Font` — `frame` は `Font -> String`。先頭から見て `rows ≤ termsize[1] - 1 && cols ≤ termsize[2]` を満たす最初の Font。なければ `last(fonts)`。

- [ ] **Step 1: 失敗するテストを書く**

```julia
using TerminalClock: framesize, select_font, FONTS

@testset "framesize" begin
    @test framesize("12:34:56") == (1, 8)
    @test framesize("ab\nabcd") == (2, 4)
    @test framesize(clock(Time(12, 34, 56))) == (9, 79)  # ASCII の実測値
end

@testset "default candidates" begin
    @test length(FONTS) == 3
    @test clock_frame(FONTS[end], Time(1, 2, 3)) == "01:02:03"
    @test clock_frame(FONTS[2], Time(1, 2, 3)) == "0️⃣1️⃣:0️⃣2️⃣:0️⃣3️⃣"
end

@testset "select_font" begin
    f = font -> clock_frame(font, Time(12, 34, 56))
    big_rows, big_cols = framesize(f(FONTS[1]))
    @test select_font(FONTS, f, (big_rows + 1, big_cols)) === FONTS[1]
    @test select_font(FONTS, f, (big_rows, big_cols)) === FONTS[2]      # 行が 1 足りない
    @test select_font(FONTS, f, (40, 14)) === FONTS[2]                  # keycap は幅 14
    @test select_font(FONTS, f, (40, 13)) === FONTS[3]
end

@testset "select_font falls back to last" begin
    f = font -> clock_frame(font, Time(12, 34, 56))
    @test select_font(FONTS, f, (1, 4)) === FONTS[end]
end

@testset "select_font respects order" begin
    f = font -> clock_frame(font, Time(12, 34, 56))
    fonts = [FONTS[3], FONTS[1]]   # 小さい方が先に登録されている
    @test select_font(fonts, f, (100, 300)) === FONTS[3]
end
```

preference の testset（既存の `"preference"`）に、`set_dials([unicodebox, ascii2])` → 別プロセスで `length(TerminalClock.FONTS) == 4` と `clock(dt)` が UnicodeBox の参照と一致すること → `clear_dials()` → 別プロセスで `length(FONTS) == 3` と ASCII の参照に一致すること、を既存の `activate_and_run` の書き方で追加する。`LocalPreferences.toml` に `tomlfiles` の配列が保存されることも確かめる。

- [ ] **Step 2: テストが失敗することを確かめる**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: FAIL（`framesize` / `select_font` が未定義、`length(FONTS) == 1`）

- [ ] **Step 3: Interfaces に書いた関数を実装し、`const FONTS` を `load_fonts()` にする**

`set_dials(::AbstractVector)` の docstring には「先頭から順に、収まる最初の文字盤が使われる」「再起動が必要」と書く。

- [ ] **Step 4: `docs/src/dials.md` に複数登録を追記する**

追記する内容: `set_dials([...])` の例、候補の順序（登録順 → Keycap → Text、登録がなければ `tomlfile` または ASCII が先頭）、単発フレームは候補の先頭を使うこと、復旧手順で `tomlfiles` も消すこと。

- [ ] **Step 5: すべてのテストが通ることを確かめる**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: PASS

- [ ] **Step 6: コミット**

```bash
git add src/TerminalClock.jl test/runtests.jl docs/src/dials.md
git commit -m "Register multiple dial candidates and select by terminal size"
```

---

### Task 4: ライブ表示の自動切り替えと画面全体の消去

**Files:**
- Modify: `src/TerminalClock.jl`（`clock()`、`_countdown`、`_stopwatch`、`clearlines` の利用をやめる）
- Modify: `test/runtests.jl`（既存の `clear=_ -> nothing` を新しい形に）、`test/verification.jl`（JET 呼び出しの `clear`）、`test/countdown_accuracy.jl` / `test/stopwatch_accuracy.jl` / `test/repl_accuracy.jl`（`clear` を渡している箇所）
- Modify: `docs/src/usage.md`（小さいペインで自動的に小さい文字盤になること、時計専用ペインを想定して画面全体を消すこと）、`docs/src/dials.md`
- Test: `test/runtests.jl`

**Interfaces:**
- Consumes: `FONTS`, `select_font`, `clock_frame`, `stopwatch_frame`（Task 1・3）
- Produces:
  - `const CLEAR_SCREEN = "\e[H\e[2J"`
  - `_live_frame(fonts, frame, termsize::Tuple{Int,Int})::String` — `frame(select_font(fonts, frame, termsize))`。
  - 3 つのループの共通キーワード: `io::IO=stdout`, `fonts=FONTS`, `termsize=() -> displaysize(io)`, `clear=() -> print(io, CLEAR_SCREEN)`, `render=t -> println(io, _live_frame(fonts, f -> <frame_fn>(f, t), termsize()))`。`<frame_fn>` は countdown と clock が `clock_frame`、stopwatch が `stopwatch_frame`。
  - ループの順序は各回「`clear()` → `render(t)` → 終了判定 → `wait`」。`clear` は引数なしになる（従来の `clear(height)` と高さの計算は消す）。
  - `clock()` は `_clock(; now=Dates.now, wait=sleep, io, fonts, termsize, clear, render)` を呼ぶ。`_clock` は 0.5 秒ごとに描画し、`InterruptException` で `nothing` を返す（それ以外の例外は rethrow）。
  - `clearlines` / `clearline` はどこからも使われなくなったら削除する。

- [ ] **Step 1: 既存のテストを新しい `clear` の形に直す**

`clear=_ -> nothing` をすべて `clear=() -> nothing` に置き換える（`test/runtests.jl`、`test/verification.jl`、accuracy スクリプト）。

- [ ] **Step 2: 失敗するテストを書く**

```julia
@testset "live display switches dials by terminal size" begin
    sizes = [(40, 200), (3, 40), (2, 8)]   # 大 / keycap（幅 14）/ text
    calls = Ref(0)
    ticks = Ref(UInt64(0))
    io = IOBuffer()
    TerminalClock._countdown(Time(0, 0, 2); io,
        now_ns=() -> ticks[],
        wait=seconds -> (ticks[] += round(UInt64, seconds * 1e9)),
        termsize=() -> sizes[(calls[] += 1)])
    out = String(take!(io))
    frames = split(out, TerminalClock.CLEAR_SCREEN; keepempty=false)
    @test startswith(out, TerminalClock.CLEAR_SCREEN)
    @test length(frames) == 3
    @test frames[1] == clock(Time(0, 0, 2)) * "\n"                     # 大きい文字盤
    @test frames[2] == clock_frame(FONTS[2], Time(0, 0, 1)) * "\n"     # keycap
    @test frames[3] == "00:00:00\n"                                    # text
end

@testset "stopwatch live display uses stopwatch frames" begin
    io = IOBuffer()
    n = Ref(0)
    TerminalClock._stopwatch(0.1; io,
        now_ns=() -> UInt64(0), wait=_ -> nothing,
        termsize=() -> ((n[] += 1) > 1 && throw(InterruptException()); (2, 20)))
    # 1 回目は keycap（幅 16 ≤ 20）。2 回目は clear の後の render 中に termsize が投げる。
    @test String(take!(io)) == TerminalClock.CLEAR_SCREEN *
          stopwatch_frame(FONTS[2], Time(0)) * "\n" * TerminalClock.CLEAR_SCREEN
end

@testset "clock live display leaves the last frame" begin
    io = IOBuffer()
    n = Ref(0)
    TerminalClock._clock(; io, now=() -> DateTime(2026, 1, 1, 12, 34, 56),
        wait=_ -> (n[] += 1) == 2 && throw(InterruptException()),
        termsize=() -> (2, 10))   # keycap（幅 14）は入らず text になる
    @test String(take!(io)) == repeat(TerminalClock.CLEAR_SCREEN * "12:34:56\n", 2)
end
```

countdown のテストは既存の `simulate` と同じく、`wait` が仮想時計を進める。2 秒の countdown なので表示は 2 → 1 → 0 の 3 フレームになる。

- [ ] **Step 3: テストが失敗することを確かめる**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: FAIL（`io` / `termsize` キーワードがない、`CLEAR_SCREEN` / `_clock` が未定義）

- [ ] **Step 4: Interfaces の通りにループを実装する**

- [ ] **Step 5: JET のテストを更新する**

`test/verification.jl` に `JET.@test_call TerminalClock._clock(; now=() -> DateTime(2026), wait=_ -> nothing, render=_ -> nothing, clear=() -> nothing, termsize=() -> (24, 80))` を追加する（`@test_call` は解析するだけで実行しないので、無限ループにはならない）。

- [ ] **Step 6: すべてのテストが通ることを確かめる**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: PASS（既存の countdown / stopwatch timing テストを含む）

- [ ] **Step 7: 実際のターミナルで確かめる**

tmux などで小さいペインを作り、`julia --project -e 'using TerminalClock; countdown(second=20)'` を実行しながらペインの大きさを変える。大 → keycap → text と切り替わり、残骸が残らず、終了時に最後のフレーム（`00:00:00` 相当）が残ることを目で確認する。

- [ ] **Step 8: ドキュメントを更新してコミット**

```bash
git add src/TerminalClock.jl test docs/src/usage.md docs/src/dials.md
git commit -m "Switch dials automatically in live displays and clear the full screen"
```
