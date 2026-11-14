///| 在所有后端上都可用的实现。

///|
/// 标准库的 `StringView::find`。
pub fn find_core(text : String, needle : String, from : Int32) -> Int32 {
  match text.unsafe_view(start=from, end=text.length()).find(needle) {
    Some(index) => from + index
    None => -1
  }
}

///|
/// 使用无检查码元读取的 MoonBit 标量循环。
pub fn find_mbt_unsafe(text : String, needle : String, from : Int32) -> Int32 {
  if needle.length() != 1 {
    return find_core(text, needle, from)
  }
  let code = needle.unsafe_get(0).to_int()
  let end = text.length()
  for i in from..<end {
    if text.unsafe_get(i).to_int() == code {
      return i
    }
  }
  -1
}

///|
/// 使用带边界检查码元读取的 MoonBit 标量循环。
pub fn find_mbt_checked(text : String, needle : String, from : Int32) -> Int32 {
  if needle.length() != 1 {
    return find_core(text, needle, from)
  }
  let code = needle.code_unit_at(0).to_int()
  let end = text.length()
  for i in from..<end {
    if text.code_unit_at(i).to_int() == code {
      return i
    }
  }
  -1
}
