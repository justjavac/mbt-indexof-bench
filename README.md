# mbt-indexof-bench

字符串 indexOf 搜索在全部 MoonBit 后端（`native`、`llvm`、`js`、`wasm`、
`wasm-gc`）上的性能对比，同一份纯 MoonBit 代码，覆盖
Linux / Windows / macOS。

## 结论

- **Windows native（MSVC）的 `core` find 比 Linux native 慢 100~200 倍**
  （全扫 505 µs 对 3.04 µs；多码元 `</article>` 用例 916 µs 对
  3.35 µs）。同一 Windows 构建下，手写标量 MoonBit 循环速度正常
  （24~32 µs），说明慢在 core 库 find 的 MSVC 路径内部，而非
  MoonBit 代码生成。
- **js 是整体最快的后端**（V8 memchr 级搜索，64K 扫描低至
  0.3~1.7 µs），但有一个可复现的异常：在 mixed 数据集中搜索 `★`
  在所有操作系统上都比其他单码元搜索慢 20~50 倍（31~77 µs），而对
  同一文本手写 `charCodeAt` 循环速度正常。
- **wasm 的 `core` find 使用 128 位 SIMD**（3~11 µs）；**wasm-gc 没有**
  （14~78 µs，标量）。
- **实验性 llvm 后端的 `core` find 在所有平台上都是标量实现**
  （18~91 µs）。在 Linux/macOS 上比 C native 后端慢约 10 倍，但在
  Windows 上反而比 MSVC 构建的 native 后端**快约 10 倍**。
- **边界检查在 native、llvm、wasm-gc 上零开销**，wasm 上约 2 倍，
  js 上只是噪声。
- 浅层搜索（needle 在前十几个码元内）在所有后端都被调用开销主导，
  各实现之间无法区分。

## 简介

在优化 [`justjavac/html`](https://github.com/justjavac/moonbit-html)
时发现 native 后端解析反而慢于 js/wasm。本仓库把搜索操作单独抽出来
定位原因：三个最简纯 MoonBit 实现（标准库 `StringView::find`、无检查
与带检查的标量循环），在 6 种 65,536 码元的固定种子数据集（ascii
深/浅扫描、html、CJK、混合、无匹配，外加 3 个多码元 needle）上逐
后端计时，oracle 测试保证各实现结果一致。

## 本地运行

```sh
moon bench --target native --release
moon bench --target llvm --release   # 需要 nightly 工具链
moon bench --target js --release     # 需要 Node.js
moon bench --target wasm --release
moon bench --target wasm-gc --release
moon test --target all               # oracle 一致性检查
```

## CI

`.github/workflows/bench.yml` 运行矩阵
（ubuntu / windows / macos）×（latest / nightly 工具链），结果发布在
step summary 和 artifacts 中。实验性的 `llvm` 目标在 nightly 通道上运行。

## 结果

来自 2026-11-14 的 CI 运行（MoonBit latest 稳定版；`llvm` 取自
nightly）。文本为 65,536 个 UTF-16 码元，数值越小越好。

### ubuntu-latest（llvm：nightly 工具链；其余：latest）

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 2.38 µs | 26.79 µs | 291.8 ns | 3.03 µs | 13.63 µs |
| core / ascii dense | 6.5 ns | 22.2 ns | 9.2 ns | 25.2 ns | 12.1 ns |
| core / html | 6.1 ns | 10.4 ns | 9.2 ns | 23.8 ns | 11.4 ns |
| core / cjk | 1.60 µs | 17.96 µs | 1.03 µs | 2.03 µs | 8.80 µs |
| core / mixed | 2.39 µs | 26.89 µs | 30.74 µs | 3.04 µs | 13.23 µs |
| core / no match | 3.04 µs | 35.82 µs | 421.1 ns | 4.11 µs | 17.86 µs |
| core / html href | 1.83 µs | 36.78 µs | 157.7 ns | 3.10 µs | 11.56 µs |
| core / html close | 3.24 µs | 67.79 µs | 22.09 µs | 5.78 µs | 32.22 µs |
| core / cjk word | 1.76 µs | 36.60 µs | 1.07 µs | 3.07 µs | 13.07 µs |
| mbt unsafe / ascii deep | 11.63 µs | 13.46 µs | 75.92 µs | 14.09 µs | 13.88 µs |
| mbt unsafe / ascii dense | 8.4 ns | 13.2 ns | 18.9 ns | 27.0 ns | 8.7 ns |
| mbt unsafe / html | 6.1 ns | 9.7 ns | 5.4 ns | 22.0 ns | 6.2 ns |
| mbt unsafe / cjk | 7.61 µs | 8.98 µs | 50.48 µs | 9.47 µs | 9.06 µs |
| mbt unsafe / mixed | 11.51 µs | 13.45 µs | 76.96 µs | 13.91 µs | 13.57 µs |
| mbt unsafe / no match | 15.68 µs | 17.92 µs | 105.59 µs | 18.68 µs | 18.17 µs |
| mbt unsafe / html href | 1.78 µs | 36.78 µs | 162.4 ns | 3.05 µs | 12.23 µs |
| mbt unsafe / html close | 3.21 µs | 67.86 µs | 22.17 µs | 5.62 µs | 32.20 µs |
| mbt unsafe / cjk word | 1.84 µs | 36.77 µs | 1.06 µs | 3.02 µs | 11.60 µs |
| mbt checked / ascii deep | 12.01 µs | 13.46 µs | 73.72 µs | 31.25 µs | 13.48 µs |
| mbt checked / ascii dense | 10.5 ns | 14.7 ns | 19.4 ns | 33.4 ns | 8.7 ns |
| mbt checked / html | 6.2 ns | 9.4 ns | 5.5 ns | 23.5 ns | 6.2 ns |
| mbt checked / cjk | 7.78 µs | 9.05 µs | 49.14 µs | 19.98 µs | 8.86 µs |
| mbt checked / mixed | 11.22 µs | 13.49 µs | 74.40 µs | 30.13 µs | 13.43 µs |
| mbt checked / no match | 15.41 µs | 17.91 µs | 99.27 µs | 40.52 µs | 17.76 µs |
| mbt checked / html href | 1.81 µs | 36.70 µs | 159.3 ns | 3.03 µs | 11.19 µs |
| mbt checked / html close | 3.35 µs | 67.95 µs | 22.05 µs | 6.11 µs | 32.16 µs |
| mbt checked / cjk word | 1.83 µs | 36.58 µs | 1.10 µs | 3.03 µs | 11.95 µs |

### windows-latest（llvm：nightly 工具链；其余：latest）

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 374.71 µs | 33.52 µs | 1.67 µs | 6.97 µs | 29.63 µs |
| core / ascii dense | 209.9 ns | 59.3 ns | 20.5 ns | 32.9 ns | 20.7 ns |
| core / html | 43.4 ns | 46.5 ns | 18.7 ns | 30.6 ns | 19.5 ns |
| core / cjk | 254.24 µs | 22.19 µs | 3.22 µs | 4.37 µs | 19.62 µs |
| core / mixed | 381.53 µs | 33.25 µs | 70.72 µs | 6.52 µs | 29.34 µs |
| core / no match | 505.37 µs | 44.06 µs | 2.17 µs | 8.65 µs | 39.34 µs |
| core / html href | 492.49 µs | 44.51 µs | 1.15 µs | 5.77 µs | 32.60 µs |
| core / html close | 899.55 µs | 80.88 µs | 35.43 µs | 10.43 µs | 78.10 µs |
| core / cjk word | 493.48 µs | 44.35 µs | 3.29 µs | 5.70 µs | 31.86 µs |
| mbt unsafe / ascii deep | 24.10 µs | 14.59 µs | 206.20 µs | 29.37 µs | 29.31 µs |
| mbt unsafe / ascii dense | 42.0 ns | 43.2 ns | 32.7 ns | 36.8 ns | 16.1 ns |
| mbt unsafe / html | 39.8 ns | 40.3 ns | 10.3 ns | 28.5 ns | 9.6 ns |
| mbt unsafe / cjk | 16.16 µs | 9.81 µs | 125.67 µs | 19.66 µs | 19.59 µs |
| mbt unsafe / mixed | 24.28 µs | 14.62 µs | 188.02 µs | 29.34 µs | 29.24 µs |
| mbt unsafe / no match | 32.40 µs | 19.44 µs | 246.23 µs | 38.96 µs | 39.09 µs |
| mbt unsafe / html href | 493.15 µs | 45.23 µs | 1.12 µs | 5.73 µs | 33.10 µs |
| mbt unsafe / html close | 916.37 µs | 81.10 µs | 34.30 µs | 10.48 µs | 78.31 µs |
| mbt unsafe / cjk word | 500.18 µs | 44.66 µs | 3.24 µs | 5.77 µs | 32.38 µs |
| mbt checked / ascii deep | 25.65 µs | 28.95 µs | 190.97 µs | 66.45 µs | 29.17 µs |
| mbt checked / ascii dense | 44.1 ns | 48.2 ns | 32.1 ns | 50.0 ns | 16.3 ns |
| mbt checked / html | 39.5 ns | 39.8 ns | 11.5 ns | 29.2 ns | 9.8 ns |
| mbt checked / cjk | 17.16 µs | 19.39 µs | 127.23 µs | 44.40 µs | 19.47 µs |
| mbt checked / mixed | 25.28 µs | 29.30 µs | 189.68 µs | 67.53 µs | 29.14 µs |
| mbt checked / no match | 33.24 µs | 39.25 µs | 242.45 µs | 87.92 µs | 38.91 µs |
| mbt checked / html href | 495.83 µs | 44.73 µs | 1.13 µs | 5.84 µs | 32.75 µs |
| mbt checked / html close | 901.64 µs | 81.84 µs | 34.11 µs | 10.34 µs | 78.22 µs |
| mbt checked / cjk word | 495.81 µs | 44.25 µs | 3.28 µs | 5.73 µs | 32.86 µs |

### macos-latest（llvm：nightly 工具链；其余：latest）

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 3.06 µs | 19.32 µs | 1.18 µs | 6.35 µs | 28.72 µs |
| core / ascii dense | 8.7 ns | 18.0 ns | 12.2 ns | 30.9 ns | 19.3 ns |
| core / html | 7.5 ns | 9.9 ns | 13.2 ns | 27.2 ns | 13.9 ns |
| core / cjk | 2.15 µs | 12.56 µs | 2.93 µs | 4.00 µs | 19.52 µs |
| core / mixed | 3.39 µs | 19.05 µs | 77.40 µs | 6.24 µs | 28.97 µs |
| core / no match | 4.33 µs | 25.16 µs | 1.61 µs | 7.90 µs | 37.66 µs |
| core / html href | 2.96 µs | 24.68 µs | 817.0 ns | 5.35 µs | 27.18 µs |
| core / html close | 5.46 µs | 47.77 µs | 32.28 µs | 10.85 µs | 51.11 µs |
| core / cjk word | 2.95 µs | 24.58 µs | 2.96 µs | 5.60 µs | 27.22 µs |
| mbt unsafe / ascii deep | 18.96 µs | 17.75 µs | 128.69 µs | 27.26 µs | 28.72 µs |
| mbt unsafe / ascii dense | 12.0 ns | 14.3 ns | 23.1 ns | 31.3 ns | 13.9 ns |
| mbt unsafe / html | 7.3 ns | 8.5 ns | 6.3 ns | 25.1 ns | 7.4 ns |
| mbt unsafe / cjk | 13.09 µs | 11.45 µs | 86.77 µs | 18.40 µs | 18.91 µs |
| mbt unsafe / mixed | 18.86 µs | 16.70 µs | 123.15 µs | 26.86 µs | 28.77 µs |
| mbt unsafe / no match | 28.80 µs | 22.30 µs | 161.73 µs | 37.16 µs | 38.34 µs |
| mbt unsafe / html href | 3.77 µs | 25.13 µs | 810.4 ns | 5.52 µs | 27.94 µs |
| mbt unsafe / html close | 6.36 µs | 46.53 µs | 29.19 µs | 10.10 µs | 49.73 µs |
| mbt unsafe / cjk word | 3.64 µs | 25.19 µs | 2.71 µs | 6.07 µs | 25.28 µs |
| mbt checked / ascii deep | 27.78 µs | 16.34 µs | 146.21 µs | 57.03 µs | 27.26 µs |
| mbt checked / ascii dense | 13.8 ns | 13.8 ns | 25.9 ns | 42.2 ns | 13.2 ns |
| mbt checked / html | 7.7 ns | 9.6 ns | 6.5 ns | 29.2 ns | 7.2 ns |
| mbt checked / cjk | 16.63 µs | 11.14 µs | 79.17 µs | 44.89 µs | 18.23 µs |
| mbt checked / mixed | 26.07 µs | 16.39 µs | 122.02 µs | 66.28 µs | 26.61 µs |
| mbt checked / no match | 32.50 µs | 22.45 µs | 163.48 µs | 82.81 µs | 37.15 µs |
| mbt checked / html href | 3.11 µs | 24.53 µs | 739.3 ns | 7.03 µs | 26.39 µs |
| mbt checked / html close | 5.55 µs | 46.10 µs | 29.78 µs | 12.12 µs | 50.93 µs |
| mbt checked / cjk word | 3.00 µs | 25.54 µs | 2.65 µs | 5.96 µs | 26.85 µs |

## 许可证

MIT
