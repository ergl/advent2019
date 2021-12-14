use "files"
use "collections"

use "debug"

type Template is Array[U8]
type Insertions is MapIs[(U8, U8), U8]

primitive ASCII
  fun apply(ch: U8): String =>
    recover String.from_utf32(ch.u32()) end

primitive ArrayToString
  fun apply(a: Array[U8] box): String =>
    let str = recover String.create(a.size()) end
    for v in a.values() do
      str.push(v)
    end
    consume str

primitive ParseInput
  fun apply(lines: FileLines): (Template val, Insertions val) ? =>
    let template = recover Template.create() end
    let insertions = recover Insertions.create() end

    var first = true
    for line in lines do
      if first then
        let l = consume val line
        for byte in l.values() do
          template.push(byte)
        end
        first = false
        continue
      end

      if line.size() == 0 then
        continue
      end

      let parts = (consume line).split(" ", 3)

      // Origin is always two bytes
      // Destination is always a single byte
      let origin = parts(0)?
      let dest = parts(2)?(0)?
      (let origin_1, let origin_2) = (origin(0)?, origin(1)?)
      insertions.insert((origin_1, origin_2), dest)
    end

    (consume val template, consume val insertions)

actor Main
  let path: String = "./input.txt"

  new create(env: Env) =>
    try
      with file = OpenFile(FilePath(env.root as AmbientAuth, path)) as File
      do
        (let template, let insertions) = ParseInput(file.lines())?
        solve(env.out, template, insertions, 10)
      end
    else
      env.err.print("Error")
    end

  fun tag solve(
    out: OutStream,
    template: Template val,
    changes_table: Insertions val,
    steps: U8)
  =>
    let frequencies = MapIs[U8, U64].create()
    var index: USize = 0
    try
      let first = template(0)?
      frequencies.upsert(first, 1, {(c,p) => c + p})
      while index < (template.size() - 1) do
        let left = template(index)?
        let right = template(index + 1)?
        frequencies.upsert(right, 1, {(c,p) => c + p})
        expand_pair(
          left,
          right,
          0,
          steps,
          changes_table,
          frequencies
        )
        index = index + 1
      end
    end

    (var max_freq: U64, var max_value: U8) = (0, 0)
    (var min_freq: U64, var min_value: U8) = (U64.max_value(), 0)

    for (c, freq) in frequencies.pairs() do
      if freq > max_freq then
        max_freq = freq
        max_value = c
      elseif freq < min_freq then
        min_freq = freq
        min_value = c
      end
    end

    out.print(
      "Most common: " + ASCII(max_value) +
      " appears " + max_freq.string() + " times."
    )
    out.print(
      "Least common: " + ASCII(min_value) +
      " appears " + min_freq.string() + " times."
    )
    out.print("Solution: " + (max_freq - min_freq).string())

  fun tag expand_pair(
    a: U8,
    b: U8,
    step: U8,
    steps: U8,
    changes: Insertions val,
    freqs: MapIs[U8, U64])
  =>
    if step == steps then
      return
    end

    try
      let c = changes((a, b))?
      freqs.upsert(c, 1, {(c,p) => c + p})
      ifdef debug then
        Debug(ASCII(a) + " plus " + ASCII(b) + " generates " + ASCII(c))
      end
      expand_pair(a, c, step + 1, steps, changes, freqs)
      expand_pair(c, b, step + 1, steps, changes, freqs)
    end
