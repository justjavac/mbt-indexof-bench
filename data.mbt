///| 确定性数据集：每个文本恰好 `size` 个 UTF-16 码元，

///| 由固定种子的 LCG 生成，所有后端看到的输入完全一致。

///|
let size : Int32 = 65536

///|
priv struct Gen {
  mut state : Int32
}

///|
fn Gen::next(self : Gen, bound : Int32) -> Int32 {
  self.state = (self.state * 1103515245 + 12345) & 0x7FFFFFFF
  self.state % bound
}

///|
let words : Array[String] = [
  "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "theta", "lambda", "sigma",
  "omega", "parser", "string", "vector", "buffer", "window", "kernel", "driver",
  "socket", "thread", "render",
]

///|
let symbols : Array[String] = [
  "←", "→", "↑", "↓", "☆", "♠", "♥", "♦", "♣", "±", "×", "÷",
  "≠", "≈",
]

///|
/// 用 `fill` 构建文本，然后补齐或截断到恰好 `size` 个码元。
fn build(fill : (StringBuilder) -> Unit) -> String {
  let buf = StringBuilder()
  fill(buf)
  let text = buf.to_string()
  if text.length() >= size {
    text.unsafe_substring(start=0, end=size)
  } else {
    let pad = StringBuilder()
    pad.write_string(text)
    for _ in text.length()..<size {
      pad.write_char('x')
    }
    pad.to_string()
  }
}

///|
fn with_char_at(text : String, pos : Int32, ch : Char) -> String {
  let buf = StringBuilder()
  buf.write_substring(text, 0, pos)
  buf.write_char(ch)
  buf.write_substring(text, pos + 1, text.length() - pos - 1)
  buf.to_string()
}

///|
fn with_str_at(text : String, pos : Int32, s : String) -> String {
  let buf = StringBuilder()
  buf.write_substring(text, 0, pos)
  buf.write_string(s)
  buf.write_substring(text, pos + s.length(), text.length() - pos - s.length())
  buf.to_string()
}

///|
/// 类英文散文，除 3/4 深度处外没有 `<`。
let ascii : String = {
  let base = build(fn(buf) {
    let gen = { state: 42, }
    for i in 0..<(size / 6) {
      buf.write_string(words[gen.next(words.length())])
      buf.write_char(if i % 9 == 8 { '.' } else { ' ' })
    }
  })
  with_char_at(base, 49152, '<')
}

///|
/// 每 13 个码元一个 `<`：浅层扫描，频繁提前命中。
let ascii_dense : String = build(fn(buf) {
  let gen = { state: 7, }
  for i in 0..<size {
    if i % 13 == 12 {
      buf.write_char('<')
    } else {
      buf.write_char(('a'.to_int() + gen.next(26)).unsafe_to_char())
    }
  }
})

///|
/// 充满 `<` 的标签汤；"href=" 在 1/2 深度，"</article>" 靠近末尾。
let html_like : String = {
  let base = build(fn(buf) {
    let gen = { state: 99, }
    for n in 0..<(size / 24) {
      buf.write_string("<div class=\"c")
      buf.write_string(gen.next(100).to_string())
      buf.write_string("\" id=\"i")
      buf.write_string(n.to_string())
      buf.write_string("\">")
      buf.write_string(words[gen.next(words.length())])
      buf.write_string("</div>")
    }
  })
  let with_href = with_str_at(base, 32768, "href=\"/x\"")
  with_str_at(with_href, 60000, "</article>")
}

///|
/// [0x4E00, 0x9F00) 范围内的 CJK 字符，排除 '语' (0x8BED)，
/// 因此注入在 1/2 深度处的 '语' / '语言' 是唯一首次出现。
/// '龘' (0x9F98) 保证不存在。
let cjk : String = {
  let base = build(fn(buf) {
    let gen = { state: 1234, }
    for _ in 0..<size {
      let mut code = 0x4E00 + gen.next(0x9F00 - 0x4E00)
      if code >= 0x8BED {
        code += 1
      }
      buf.write_char(code.unsafe_to_char())
    }
  })
  with_str_at(base, 32768, "语言")
}

///|
/// ASCII 单词、CJK 字符与符号交错；'★' 在 3/4 深度。
let mixed : String = {
  let base = build(fn(buf) {
    let gen = { state: 555, }
    for _ in 0..<(size / 24) {
      for _ in 0..<8 {
        buf.write_char(('a'.to_int() + gen.next(26)).unsafe_to_char())
      }
      for _ in 0..<8 {
        buf.write_char((0x4E00 + gen.next(0x9F00 - 0x4E00)).unsafe_to_char())
      }
      for _ in 0..<8 {
        buf.write_string(symbols[gen.next(symbols.length())])
      }
    }
  })
  with_char_at(base, 49152, '★')
}

///|
/// 纯 ASCII 小写字母，完全没有 `<`：全扫描最坏情况。
let no_match : String = build(fn(buf) {
  let gen = { state: 31337, }
  for _ in 0..<size {
    buf.write_char(('a'.to_int() + gen.next(26)).unsafe_to_char())
  }
})
