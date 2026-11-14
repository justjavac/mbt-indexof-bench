///| 针对所有后端可用实现的基准测试。

///|
fn bench1(
  it : @bench.T,
  f : (String, String, Int32) -> Int32,
  text : String,
  needle : String,
) -> Unit {
  it.bench(fn() { it.keep(f(text, needle, 0)) })
}

///|
test "core / ascii deep" (it : @bench.T) {
  bench1(it, find_core, ascii, "<")
}

///|
test "core / ascii dense" (it : @bench.T) {
  bench1(it, find_core, ascii_dense, "<")
}

///|
test "core / html" (it : @bench.T) {
  bench1(it, find_core, html_like, "<")
}

///|
test "core / cjk" (it : @bench.T) {
  bench1(it, find_core, cjk, "语")
}

///|
test "core / mixed" (it : @bench.T) {
  bench1(it, find_core, mixed, "★")
}

///|
test "core / no match" (it : @bench.T) {
  bench1(it, find_core, no_match, "<")
}

///|
test "core / html href" (it : @bench.T) {
  bench1(it, find_core, html_like, "href=\"/x\"")
}

///|
test "core / html close" (it : @bench.T) {
  bench1(it, find_core, html_like, "</article>")
}

///|
test "core / cjk word" (it : @bench.T) {
  bench1(it, find_core, cjk, "语言")
}

///|
test "mbt unsafe / ascii deep" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, ascii, "<")
}

///|
test "mbt unsafe / ascii dense" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, ascii_dense, "<")
}

///|
test "mbt unsafe / html" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, html_like, "<")
}

///|
test "mbt unsafe / cjk" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, cjk, "语")
}

///|
test "mbt unsafe / mixed" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, mixed, "★")
}

///|
test "mbt unsafe / no match" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, no_match, "<")
}

///|
test "mbt unsafe / html href" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, html_like, "href=\"/x\"")
}

///|
test "mbt unsafe / html close" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, html_like, "</article>")
}

///|
test "mbt unsafe / cjk word" (it : @bench.T) {
  bench1(it, find_mbt_unsafe, cjk, "语言")
}

///|
test "mbt checked / ascii deep" (it : @bench.T) {
  bench1(it, find_mbt_checked, ascii, "<")
}

///|
test "mbt checked / ascii dense" (it : @bench.T) {
  bench1(it, find_mbt_checked, ascii_dense, "<")
}

///|
test "mbt checked / html" (it : @bench.T) {
  bench1(it, find_mbt_checked, html_like, "<")
}

///|
test "mbt checked / cjk" (it : @bench.T) {
  bench1(it, find_mbt_checked, cjk, "语")
}

///|
test "mbt checked / mixed" (it : @bench.T) {
  bench1(it, find_mbt_checked, mixed, "★")
}

///|
test "mbt checked / no match" (it : @bench.T) {
  bench1(it, find_mbt_checked, no_match, "<")
}

///|
test "mbt checked / html href" (it : @bench.T) {
  bench1(it, find_mbt_checked, html_like, "href=\"/x\"")
}

///|
test "mbt checked / html close" (it : @bench.T) {
  bench1(it, find_mbt_checked, html_like, "</article>")
}

///|
test "mbt checked / cjk word" (it : @bench.T) {
  bench1(it, find_mbt_checked, cjk, "语言")
}

///|
test "oracle / common implementations agree" {
  let cases : Array[(String, String, Int32)] = [
    (ascii, "<", 49152),
    (ascii_dense, "<", 12),
    (html_like, "<", 0),
    (cjk, "语", 32768),
    (mixed, "★", 49152),
    (no_match, "<", -1),
    (html_like, "href=\"/x\"", 32768),
    (html_like, "</article>", 60000),
    (cjk, "语言", 32768),
  ]
  for case in cases {
    let (text, needle, expected) = case
    assert_eq(find_core(text, needle, 0), expected)
    assert_eq(find_mbt_unsafe(text, needle, 0), expected)
    assert_eq(find_mbt_checked(text, needle, 0), expected)
  }
}
