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

- **js 与 native 同属第一梯队**：js 单码元扫描 0.4–3.6 µs（V8
  memchr 级，Ubuntu 上最快）；native 的 `core` find 为 1.5–5.2 µs。
  唯一异常仍是 js 在 mixed 数据集搜 `★`：28–94 µs，比同平台 CJK
  扫描慢 9–30 倍，比 native 慢 13–45 倍；同一文本手写 `charCodeAt`
  循环耗时与其他数据集一致（75–166 µs），异常只在 V8 的
  `indexOf` 本身。
- **长 needle 深扫 native 反超 js**：`</article>`（11 码元、靠近
  末尾）native 4.0–5.2 µs 对 js 25.5–34.4 µs（5–7 倍）；短
  needle（`href="/x"`、`语言`）两者互有胜负。
- **稳定版的 Windows MSVC native 曾慢约 100 倍**（全扫 505 µs 对
  Linux 3.0 µs），nightly 已修复（2.9 µs，与 Linux 的 3.9 µs
  持平）。
- **wasm 的 `core` find 有 128 位 SIMD**（2.0–6.9 µs）；
  **wasm-gc 是标量**（14–45 µs）。
- **llvm 后端全平台标量**（12–70 µs），是 nightly 下最慢的原生
  后端。
- **边界检查**：wasm 约 1.65 倍；Windows 的 native 约 1.5 倍、
  llvm 约 2 倍；macOS 的 native 约 1.4–1.7 倍、llvm 约 1.2 倍；
  js 与 wasm-gc 全平台零开销。
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
| core / ascii deep | 2.94 µs | 23.18 µs | 355.9 ns | 3.53 µs | 20.91 µs |
| core / ascii dense | 7.7 ns | 18.6 ns | 12.3 ns | 21.3 ns | 16.6 ns |
| core / html | 6.5 ns | 8.0 ns | 11.5 ns | 20.7 ns | 11.9 ns |
| core / cjk | 1.97 µs | 15.43 µs | 1.50 µs | 2.37 µs | 13.99 µs |
| core / mixed | 2.94 µs | 23.13 µs | 44.67 µs | 3.53 µs | 20.96 µs |
| core / no match | 3.91 µs | 30.82 µs | 515.0 ns | 4.70 µs | 27.78 µs |
| core / html href | 2.85 µs | 30.40 µs | 201.9 ns | 3.62 µs | 13.86 µs |
| core / html close | 5.20 µs | 55.63 µs | 26.86 µs | 6.60 µs | 34.74 µs |
| core / cjk word | 2.87 µs | 30.59 µs | 1.52 µs | 3.69 µs | 13.85 µs |
| mbt unsafe / ascii deep | 12.73 µs | 12.75 µs | 75.44 µs | 20.71 µs | 20.85 µs |
| mbt unsafe / ascii dense | 9.9 ns | 12.5 ns | 29.5 ns | 23.5 ns | 12.4 ns |
| mbt unsafe / html | 6.4 ns | 6.8 ns | 6.3 ns | 18.3 ns | 7.1 ns |
| mbt unsafe / cjk | 8.50 µs | 8.50 µs | 51.10 µs | 13.83 µs | 13.93 µs |
| mbt unsafe / mixed | 12.73 µs | 12.74 µs | 76.61 µs | 20.74 µs | 20.87 µs |
| mbt unsafe / no match | 16.97 µs | 16.97 µs | 99.15 µs | 27.83 µs | 27.93 µs |
| mbt unsafe / html href | 2.85 µs | 30.39 µs | 202.0 ns | 3.62 µs | 13.84 µs |
| mbt unsafe / html close | 5.20 µs | 55.54 µs | 26.91 µs | 6.60 µs | 34.69 µs |
| mbt unsafe / cjk word | 2.87 µs | 30.53 µs | 1.52 µs | 3.69 µs | 13.84 µs |
| mbt checked / ascii deep | 12.76 µs | 12.73 µs | 75.26 µs | 33.98 µs | 20.85 µs |
| mbt checked / ascii dense | 11.2 ns | 10.5 ns | 27.6 ns | 27.1 ns | 12.3 ns |
| mbt checked / html | 6.4 ns | 6.8 ns | 6.4 ns | 19.2 ns | 7.2 ns |
| mbt checked / cjk | 8.50 µs | 8.50 µs | 51.13 µs | 22.66 µs | 13.93 µs |
| mbt checked / mixed | 12.74 µs | 12.73 µs | 76.74 µs | 34.02 µs | 20.78 µs |
| mbt checked / no match | 16.97 µs | 16.96 µs | 99.69 µs | 45.35 µs | 28.00 µs |
| mbt checked / html href | 2.86 µs | 30.35 µs | 202.8 ns | 3.62 µs | 13.85 µs |
| mbt checked / html close | 5.19 µs | 55.53 µs | 26.94 µs | 6.60 µs | 34.64 µs |
| mbt checked / cjk word | 2.87 µs | 30.56 µs | 1.52 µs | 3.69 µs | 13.84 µs |

### windows-latest

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 2.19 µs | 26.36 µs | 1.88 µs | 3.03 µs | 23.84 µs |
| core / ascii dense | 36.9 ns | 46.6 ns | 15.5 ns | 27.7 ns | 20.2 ns |
| core / html | 34.8 ns | 35.4 ns | 14.1 ns | 26.7 ns | 17.2 ns |
| core / cjk | 1.49 µs | 17.53 µs | 3.02 µs | 2.06 µs | 15.87 µs |
| core / mixed | 2.26 µs | 26.34 µs | 28.43 µs | 3.10 µs | 22.19 µs |
| core / no match | 2.92 µs | 34.97 µs | 2.50 µs | 4.07 µs | 29.77 µs |
| core / html href | 2.24 µs | 37.33 µs | 1.30 µs | 3.46 µs | 15.01 µs |
| core / html close | 4.04 µs | 70.00 µs | 25.53 µs | 6.26 µs | 28.33 µs |
| core / cjk word | 2.25 µs | 37.54 µs | 3.09 µs | 3.46 µs | 15.28 µs |
| mbt unsafe / ascii deep | 13.62 µs | 13.58 µs | 139.54 µs | 22.04 µs | 22.66 µs |
| mbt unsafe / ascii dense | 35.9 ns | 37.2 ns | 16.0 ns | 29.4 ns | 18.7 ns |
| mbt unsafe / html | 32.5 ns | 33.0 ns | 7.6 ns | 24.6 ns | 10.3 ns |
| mbt unsafe / cjk | 9.18 µs | 9.09 µs | 92.64 µs | 14.77 µs | 14.90 µs |
| mbt unsafe / mixed | 13.62 µs | 13.63 µs | 145.69 µs | 22.26 µs | 25.12 µs |
| mbt unsafe / no match | 18.16 µs | 18.08 µs | 165.94 µs | 29.37 µs | 36.06 µs |
| mbt unsafe / html href | 2.24 µs | 37.42 µs | 1.30 µs | 3.47 µs | 16.01 µs |
| mbt unsafe / html close | 4.05 µs | 68.87 µs | 25.50 µs | 6.27 µs | 29.33 µs |
| mbt unsafe / cjk word | 2.27 µs | 37.62 µs | 3.04 µs | 3.45 µs | 15.53 µs |
| mbt checked / ascii deep | 20.31 µs | 27.22 µs | 138.17 µs | 36.07 µs | 22.69 µs |
| mbt checked / ascii dense | 37.2 ns | 46.7 ns | 31.3 ns | 33.0 ns | 14.7 ns |
| mbt checked / html | 32.5 ns | 33.2 ns | 7.4 ns | 24.8 ns | 10.2 ns |
| mbt checked / cjk | 13.60 µs | 18.09 µs | 91.78 µs | 24.14 µs | 14.77 µs |
| mbt checked / mixed | 20.65 µs | 27.18 µs | 136.20 µs | 36.09 µs | 22.12 µs |
| mbt checked / no match | 27.09 µs | 36.59 µs | 166.32 µs | 48.06 µs | 29.45 µs |
| mbt checked / html href | 2.24 µs | 37.38 µs | 1.30 µs | 3.84 µs | 14.74 µs |
| mbt checked / html close | 4.03 µs | 68.96 µs | 25.59 µs | 6.86 µs | 28.22 µs |
| mbt checked / cjk word | 2.24 µs | 37.59 µs | 3.05 µs | 3.49 µs | 14.80 µs |

### macos-latest

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 2.01 µs | 19.83 µs | 1.42 µs | 2.96 µs | 26.97 µs |
| core / ascii dense | 9.6 ns | 19.7 ns | 24.6 ns | 25.1 ns | 20.1 ns |
| core / html | 10.6 ns | 10.9 ns | 14.1 ns | 23.6 ns | 13.0 ns |
| core / cjk | 1.59 µs | 12.43 µs | 3.61 µs | 2.03 µs | 16.77 µs |
| core / mixed | 2.10 µs | 18.03 µs | 94.30 µs | 2.90 µs | 25.18 µs |
| core / no match | 2.56 µs | 24.78 µs | 1.67 µs | 3.89 µs | 34.87 µs |
| core / html href | 2.44 µs | 25.64 µs | 825.0 ns | 3.70 µs | 19.10 µs |
| core / html close | 4.64 µs | 50.44 µs | 34.43 µs | 6.91 µs | 38.04 µs |
| core / cjk word | 2.77 µs | 26.80 µs | 3.31 µs | 3.51 µs | 19.77 µs |
| mbt unsafe / ascii deep | 17.65 µs | 17.63 µs | 130.77 µs | 25.41 µs | 26.27 µs |
| mbt unsafe / ascii dense | 12.3 ns | 13.2 ns | 21.9 ns | 27.5 ns | 12.6 ns |
| mbt unsafe / html | 7.3 ns | 8.5 ns | 7.0 ns | 21.3 ns | 7.1 ns |
| mbt unsafe / cjk | 11.44 µs | 11.79 µs | 82.99 µs | 19.74 µs | 17.17 µs |
| mbt unsafe / mixed | 17.45 µs | 15.68 µs | 127.05 µs | 31.74 µs | 25.13 µs |
| mbt unsafe / no match | 23.25 µs | 23.44 µs | 164.85 µs | 40.61 µs | 33.52 µs |
| mbt unsafe / html href | 2.81 µs | 29.70 µs | 690.8 ns | 3.83 µs | 19.75 µs |
| mbt unsafe / html close | 5.15 µs | 56.79 µs | 30.31 µs | 6.33 µs | 39.16 µs |
| mbt unsafe / cjk word | 2.83 µs | 29.15 µs | 2.94 µs | 3.48 µs | 19.87 µs |
| mbt checked / ascii deep | 24.97 µs | 18.58 µs | 135.34 µs | 42.15 µs | 29.00 µs |
| mbt checked / ascii dense | 13.6 ns | 14.0 ns | 24.0 ns | 33.0 ns | 14.4 ns |
| mbt checked / html | 7.6 ns | 12.8 ns | 7.5 ns | 21.6 ns | 9.1 ns |
| mbt checked / cjk | 20.04 µs | 14.30 µs | 85.26 µs | 27.93 µs | 21.31 µs |
| mbt checked / mixed | 30.40 µs | 18.80 µs | 129.82 µs | 43.58 µs | 28.65 µs |
| mbt checked / no match | 34.98 µs | 27.81 µs | 188.03 µs | 55.64 µs | 35.35 µs |
| mbt checked / html href | 2.70 µs | 27.65 µs | 715.2 ns | 3.39 µs | 20.95 µs |
| mbt checked / html close | 4.93 µs | 48.92 µs | 30.80 µs | 6.24 µs | 45.04 µs |
| mbt checked / cjk word | 2.57 µs | 27.77 µs | 2.97 µs | 3.39 µs | 22.42 µs |

