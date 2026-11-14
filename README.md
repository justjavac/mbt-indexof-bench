# mbt-indexof-bench

字符串 `indexOf` 搜索在全部 MoonBit 后端（`native`、`llvm`、`js`、`wasm`、
`wasm-gc`）上的性能对比。

## 背景

在优化 [`justjavac/html`](https://github.com/justjavac/moonbit-html)
时发现 native 后端解析反而慢于 js/wasm。本仓库把搜索操作单独抽出来
定位原因。

**三个最简纯 MoonBit 实现**

1. 标准库 `StringView::find`
1. 无检查的标量循环
1. 带检查的标量循环

**65,536 码元的固定种子数据集**

1. ascii 深扫描
1. ascii 浅扫描
1. html 标签汤
1. CJK
1. 混合（ASCII / CJK / 符号）
1. 无匹配（全扫）

另加 3 个多码元 needle（`href="/x"`、`</article>`、`语言`）。

## 结论

- **js 是最快的后端**：单码元扫描 0.2–2.5 µs（V8 memchr 级）。唯一
  异常：mixed 数据集搜 `★` 在三平台慢 20–40 倍（28–80 µs），同一
  文本手写 `charCodeAt` 循环速度正常。
- **native 的 `core` find 在三平台同为最快一档**（2.2–4.7 µs），
  多码元 needle 上反超 js（4–7 µs 对 25–32 µs）。
- **稳定版的 Windows MSVC native 曾慢约 100 倍**（全扫 505 µs 对
  Linux 3.0 µs），nightly 已修复（2.9 µs，与 Linux 持平）。
- **wasm 的 `core` find 有 128 位 SIMD**（2–7 µs）；**wasm-gc 是标量**
  （15–44 µs）。
- **llvm 后端全平台标量**（18–74 µs），是 nightly 下最慢的原生后端。
- **边界检查**：wasm 约 1.6–2 倍；其余后端多为零开销（macOS native
  约 2.8 倍、Windows native 约 1.5 倍除外）。
- **浅层搜索**（needle 在前十几个码元内命中）由调用开销主导，
  各实现无差异。

## 本地运行

全部使用 nightly 工具链：

```sh
moon bench --target native --release
moon bench --target llvm --release
moon bench --target js --release     # 需要 Node.js
moon bench --target wasm --release
moon bench --target wasm-gc --release
moon test --target all               # 一致性检查
```

## CI

`.github/workflows/bench.yml` 在 ubuntu / windows / macos 上运行，全部
使用 nightly 工具链，结果发布在 step summary 和 artifacts 中。

## 结果

来自 2026-11-14 的 CI 运行（MoonBit nightly 工具链）。文本为 65,536
个 UTF-16 码元，数值越小越好。

### ubuntu-latest

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 2.69 µs | 26.93 µs | 458.6 ns | 3.00 µs | 21.93 µs |
| core / ascii dense | 9.9 ns | 22.2 ns | 13.5 ns | 27.6 ns | 19.3 ns |
| core / html | 8.5 ns | 10.8 ns | 13.5 ns | 26.5 ns | 15.4 ns |
| core / cjk | 1.79 µs | 17.94 µs | 1.35 µs | 2.02 µs | 14.63 µs |
| core / mixed | 2.64 µs | 26.80 µs | 35.92 µs | 3.00 µs | 21.93 µs |
| core / no match | 3.49 µs | 35.75 µs | 586.3 ns | 3.97 µs | 29.25 µs |
| core / html href | 2.84 µs | 36.72 µs | 238.6 ns | 3.43 µs | 14.64 µs |
| core / html close | 5.18 µs | 68.03 µs | 25.40 µs | 6.22 µs | 28.21 µs |
| core / cjk word | 2.83 µs | 36.59 µs | 1.34 µs | 3.42 µs | 14.70 µs |
| mbt unsafe / ascii deep | 13.50 µs | 13.45 µs | 135.15 µs | 21.90 µs | 21.90 µs |
| mbt unsafe / ascii dense | 13.6 ns | 13.2 ns | 30.4 ns | 29.0 ns | 13.5 ns |
| mbt unsafe / html | 8.4 ns | 9.6 ns | 7.1 ns | 24.4 ns | 9.5 ns |
| mbt unsafe / cjk | 9.13 µs | 9.02 µs | 89.55 µs | 14.61 µs | 14.63 µs |
| mbt unsafe / mixed | 13.48 µs | 13.50 µs | 134.63 µs | 21.92 µs | 21.88 µs |
| mbt unsafe / no match | 17.97 µs | 17.92 µs | 161.74 µs | 29.20 µs | 29.19 µs |
| mbt unsafe / html href | 2.84 µs | 36.85 µs | 237.6 ns | 3.44 µs | 14.87 µs |
| mbt unsafe / html close | 5.17 µs | 67.88 µs | 25.41 µs | 6.25 µs | 27.97 µs |
| mbt unsafe / cjk word | 2.83 µs | 36.58 µs | 1.34 µs | 3.42 µs | 14.67 µs |
| mbt checked / ascii deep | 13.47 µs | 13.47 µs | 134.80 µs | 35.88 µs | 21.88 µs |
| mbt checked / ascii dense | 13.6 ns | 14.8 ns | 30.6 ns | 33.8 ns | 15.5 ns |
| mbt checked / html | 8.5 ns | 9.6 ns | 7.4 ns | 24.5 ns | 9.5 ns |
| mbt checked / cjk | 9.00 µs | 8.99 µs | 89.71 µs | 23.94 µs | 14.63 µs |
| mbt checked / mixed | 13.53 µs | 13.45 µs | 135.52 µs | 35.89 µs | 21.88 µs |
| mbt checked / no match | 17.95 µs | 18.01 µs | 162.49 µs | 48.20 µs | 29.20 µs |
| mbt checked / html href | 2.83 µs | 36.83 µs | 252.9 ns | 3.42 µs | 14.65 µs |
| mbt checked / html close | 5.17 µs | 67.96 µs | 25.41 µs | 6.22 µs | 27.97 µs |
| mbt checked / cjk word | 2.84 µs | 36.62 µs | 1.34 µs | 3.42 µs | 14.65 µs |

### windows-latest

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 2.21 µs | 26.30 µs | 1.88 µs | 3.04 µs | 22.01 µs |
| core / ascii dense | 37.0 ns | 46.1 ns | 15.4 ns | 27.9 ns | 20.1 ns |
| core / html | 35.1 ns | 35.3 ns | 14.0 ns | 26.7 ns | 16.9 ns |
| core / cjk | 1.49 µs | 17.53 µs | 3.02 µs | 2.03 µs | 14.72 µs |
| core / mixed | 2.19 µs | 26.30 µs | 28.36 µs | 3.01 µs | 22.32 µs |
| core / no match | 2.90 µs | 35.01 µs | 2.53 µs | 4.01 µs | 29.52 µs |
| core / html href | 2.24 µs | 37.39 µs | 1.31 µs | 3.46 µs | 14.77 µs |
| core / html close | 4.20 µs | 74.39 µs | 26.38 µs | 6.27 µs | 28.48 µs |
| core / cjk word | 2.24 µs | 37.51 µs | 3.16 µs | 3.46 µs | 14.76 µs |
| mbt unsafe / ascii deep | 13.85 µs | 13.57 µs | 141.45 µs | 22.78 µs | 21.97 µs |
| mbt unsafe / ascii dense | 36.2 ns | 37.2 ns | 30.7 ns | 29.4 ns | 14.6 ns |
| mbt unsafe / html | 33.1 ns | 32.9 ns | 7.3 ns | 24.4 ns | 10.3 ns |
| mbt unsafe / cjk | 9.11 µs | 9.09 µs | 90.45 µs | 14.80 µs | 14.76 µs |
| mbt unsafe / mixed | 13.75 µs | 13.58 µs | 135.33 µs | 21.99 µs | 21.99 µs |
| mbt unsafe / no match | 18.45 µs | 18.11 µs | 162.45 µs | 29.31 µs | 29.29 µs |
| mbt unsafe / html href | 2.25 µs | 37.50 µs | 1.30 µs | 3.49 µs | 14.74 µs |
| mbt unsafe / html close | 4.03 µs | 69.32 µs | 25.48 µs | 6.28 µs | 28.32 µs |
| mbt unsafe / cjk word | 2.23 µs | 37.44 µs | 3.04 µs | 3.48 µs | 14.72 µs |
| mbt checked / ascii deep | 20.33 µs | 27.14 µs | 135.85 µs | 36.08 µs | 21.98 µs |
| mbt checked / ascii dense | 37.0 ns | 37.4 ns | 30.4 ns | 32.9 ns | 14.7 ns |
| mbt checked / html | 32.9 ns | 33.2 ns | 7.3 ns | 24.8 ns | 10.3 ns |
| mbt checked / cjk | 13.59 µs | 18.05 µs | 90.33 µs | 24.11 µs | 14.67 µs |
| mbt checked / mixed | 20.32 µs | 27.16 µs | 137.01 µs | 36.05 µs | 22.04 µs |
| mbt checked / no match | 27.01 µs | 36.75 µs | 163.31 µs | 48.07 µs | 29.65 µs |
| mbt checked / html href | 2.24 µs | 37.31 µs | 1.29 µs | 3.46 µs | 14.71 µs |
| mbt checked / html close | 4.08 µs | 69.63 µs | 25.50 µs | 6.35 µs | 28.08 µs |
| mbt checked / cjk word | 2.24 µs | 37.48 µs | 3.05 µs | 3.44 µs | 14.75 µs |

### macos-latest

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 2.12 µs | 34.63 µs | 1.36 µs | 3.90 µs | 25.94 µs |
| core / ascii dense | 9.7 ns | 31.7 ns | 15.2 ns | 31.2 ns | 18.2 ns |
| core / html | 9.4 ns | 19.8 ns | 14.8 ns | 27.2 ns | 12.9 ns |
| core / cjk | 1.33 µs | 22.59 µs | 3.26 µs | 2.64 µs | 18.00 µs |
| core / mixed | 1.90 µs | 31.71 µs | 80.40 µs | 3.41 µs | 28.25 µs |
| core / no match | 2.53 µs | 38.95 µs | 1.72 µs | 4.34 µs | 36.17 µs |
| core / html href | 2.43 µs | 45.64 µs | 802.7 ns | 3.92 µs | 23.76 µs |
| core / html close | 4.68 µs | 69.50 µs | 31.97 µs | 7.15 µs | 43.77 µs |
| core / cjk word | 2.61 µs | 36.64 µs | 3.05 µs | 3.99 µs | 19.57 µs |
| mbt unsafe / ascii deep | 16.46 µs | 22.39 µs | 133.40 µs | 27.88 µs | 26.54 µs |
| mbt unsafe / ascii dense | 15.5 ns | 15.8 ns | 30.8 ns | 32.8 ns | 21.4 ns |
| mbt unsafe / html | 7.8 ns | 9.6 ns | 8.8 ns | 27.5 ns | 7.3 ns |
| mbt unsafe / cjk | 11.74 µs | 16.32 µs | 93.33 µs | 20.22 µs | 18.41 µs |
| mbt unsafe / mixed | 18.39 µs | 21.78 µs | 146.28 µs | 27.84 µs | 28.94 µs |
| mbt unsafe / no match | 25.25 µs | 27.37 µs | 214.17 µs | 39.40 µs | 36.32 µs |
| mbt unsafe / html href | 2.95 µs | 29.77 µs | 1.07 µs | 3.78 µs | 19.57 µs |
| mbt unsafe / html close | 5.56 µs | 50.27 µs | 37.68 µs | 7.02 µs | 40.71 µs |
| mbt unsafe / cjk word | 4.00 µs | 29.73 µs | 3.56 µs | 3.99 µs | 19.98 µs |
| mbt checked / ascii deep | 34.91 µs | 26.06 µs | 154.41 µs | 47.88 µs | 27.17 µs |
| mbt checked / ascii dense | 23.1 ns | 15.9 ns | 15.4 ns | 44.4 ns | 22.7 ns |
| mbt checked / html | 13.6 ns | 10.8 ns | 8.0 ns | 21.5 ns | 39.6 ns |
| mbt checked / cjk | 24.58 µs | 12.97 µs | 91.85 µs | 30.84 µs | 22.44 µs |
| mbt checked / mixed | 53.13 µs | 17.91 µs | 144.47 µs | 46.24 µs | 29.02 µs |
| mbt checked / no match | 70.43 µs | 25.52 µs | 189.37 µs | 64.87 µs | 39.16 µs |
| mbt checked / html href | 6.22 µs | 25.99 µs | 733.5 ns | 3.88 µs | 21.49 µs |
| mbt checked / html close | 8.89 µs | 50.31 µs | 32.94 µs | 6.74 µs | 42.96 µs |
| mbt checked / cjk word | 5.35 µs | 28.59 µs | 3.43 µs | 3.47 µs | 20.03 µs |

