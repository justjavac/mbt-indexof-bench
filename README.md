# mbt-indexof-bench

字符串 indexOf 搜索在全部 MoonBit 后端（`native`、`llvm`、`js`、`wasm`、
`wasm-gc`）上的性能对比，同一份纯 MoonBit 代码，覆盖
Linux / Windows / macOS。

## 结论

- **Windows MSVC native 的 `core` find 慢约 100 倍**：64K 全扫 336 µs，而
  Linux native 4.5 µs、js 1.6 µs。同一构建下手写标量循环速度正常
  （26 µs），瓶颈在 core 库的 MSVC 路径，与 MoonBit 代码生成无关。
- **js 是最快的后端**：V8 的 memchr 级搜索，多数扫描在 0.2~1.7 µs。
  唯一异常：mixed 数据集搜 `★` 在三个平台都慢 20~50 倍
  （46~111 µs），同一文本手写 `charCodeAt` 循环速度正常。
- **wasm 的 `core` find 有 128 位 SIMD**（4~8 µs）；**wasm-gc 是标量**
  （19~55 µs）。
- **llvm 后端全平台标量**：`core` find 在 Linux/macOS 比 C native 慢
  4~10 倍，在 Windows 反而比 MSVC native 快约 8 倍。
- **边界检查**：native、llvm、wasm-gc 零开销；wasm 约 2 倍。
- **浅层搜索**（needle 在前十几个码元内命中）由调用开销主导，
  各实现无差异。

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
| core / ascii deep | 3.36 µs | 30.49 µs | 361.6 ns | 5.06 µs | 22.49 µs |
| core / ascii dense | 7.7 ns | 27.8 ns | 11.3 ns | 25.2 ns | 16.1 ns |
| core / html | 6.7 ns | 14.7 ns | 11.4 ns | 23.3 ns | 10.9 ns |
| core / cjk | 2.26 µs | 20.58 µs | 1.51 µs | 3.39 µs | 14.99 µs |
| core / mixed | 3.36 µs | 30.56 µs | 45.56 µs | 5.02 µs | 22.52 µs |
| core / no match | 4.47 µs | 40.51 µs | 522.4 ns | 6.65 µs | 29.99 µs |
| core / html href | 3.87 µs | 45.95 µs | 201.3 ns | 4.44 µs | 19.33 µs |
| core / html close | 7.03 µs | 97.48 µs | 27.14 µs | 8.03 µs | 54.50 µs |
| core / cjk word | 3.80 µs | 41.71 µs | 1.54 µs | 4.41 µs | 19.26 µs |
| mbt unsafe / ascii deep | 12.80 µs | 16.18 µs | 76.09 µs | 22.47 µs | 22.43 µs |
| mbt unsafe / ascii dense | 10.4 ns | 17.4 ns | 29.7 ns | 27.4 ns | 12.5 ns |
| mbt unsafe / html | 6.5 ns | 11.9 ns | 6.1 ns | 21.8 ns | 6.9 ns |
| mbt unsafe / cjk | 8.54 µs | 10.91 µs | 51.49 µs | 14.98 µs | 15.00 µs |
| mbt unsafe / mixed | 12.83 µs | 16.57 µs | 77.10 µs | 22.45 µs | 22.39 µs |
| mbt unsafe / no match | 17.18 µs | 21.91 µs | 99.99 µs | 29.89 µs | 29.92 µs |
| mbt unsafe / html href | 3.86 µs | 45.86 µs | 200.6 ns | 4.43 µs | 19.26 µs |
| mbt unsafe / html close | 7.05 µs | 97.74 µs | 27.02 µs | 8.04 µs | 54.47 µs |
| mbt unsafe / cjk word | 3.82 µs | 41.70 µs | 1.53 µs | 4.40 µs | 19.24 µs |
| mbt checked / ascii deep | 12.96 µs | 16.40 µs | 75.38 µs | 44.94 µs | 22.45 µs |
| mbt checked / ascii dense | 12.8 ns | 17.7 ns | 27.2 ns | 38.6 ns | 12.6 ns |
| mbt checked / html | 6.5 ns | 12.0 ns | 6.2 ns | 22.6 ns | 6.9 ns |
| mbt checked / cjk | 8.58 µs | 10.83 µs | 51.34 µs | 29.93 µs | 14.97 µs |
| mbt checked / mixed | 12.91 µs | 16.26 µs | 77.25 µs | 44.89 µs | 22.48 µs |
| mbt checked / no match | 17.24 µs | 21.66 µs | 100.58 µs | 60.03 µs | 29.92 µs |
| mbt checked / html href | 3.87 µs | 45.83 µs | 200.2 ns | 4.44 µs | 19.31 µs |
| mbt checked / html close | 7.05 µs | 97.75 µs | 27.01 µs | 8.03 µs | 54.46 µs |
| mbt checked / cjk word | 3.80 µs | 41.79 µs | 1.53 µs | 4.40 µs | 19.29 µs |

### windows-latest（llvm：nightly 工具链；其余：latest）

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 260.50 µs | 30.35 µs | 1.29 µs | 4.81 µs | 21.50 µs |
| core / ascii dense | 139.6 ns | 58.1 ns | 13.1 ns | 24.1 ns | 15.8 ns |
| core / html | 29.3 ns | 44.4 ns | 12.7 ns | 22.1 ns | 12.6 ns |
| core / cjk | 167.52 µs | 20.13 µs | 2.44 µs | 3.19 µs | 14.59 µs |
| core / mixed | 260.68 µs | 30.20 µs | 50.14 µs | 4.79 µs | 21.22 µs |
| core / no match | 336.42 µs | 40.16 µs | 1.64 µs | 6.44 µs | 29.80 µs |
| core / html href | 327.59 µs | 46.44 µs | 823.4 ns | 4.61 µs | 18.77 µs |
| core / html close | 608.98 µs | 100.74 µs | 27.59 µs | 8.43 µs | 50.87 µs |
| core / cjk word | 334.69 µs | 43.05 µs | 2.50 µs | 4.72 µs | 18.84 µs |
| mbt unsafe / ascii deep | 18.20 µs | 15.74 µs | 74.66 µs | 23.42 µs | 21.19 µs |
| mbt unsafe / ascii dense | 29.3 ns | 46.3 ns | 14.9 ns | 30.0 ns | 12.1 ns |
| mbt unsafe / html | 29.3 ns | 42.3 ns | 6.7 ns | 20.9 ns | 7.4 ns |
| mbt unsafe / cjk | 13.13 µs | 11.08 µs | 54.43 µs | 14.36 µs | 14.22 µs |
| mbt unsafe / mixed | 19.46 µs | 15.70 µs | 86.85 µs | 21.26 µs | 21.48 µs |
| mbt unsafe / no match | 26.22 µs | 20.85 µs | 94.41 µs | 28.57 µs | 30.31 µs |
| mbt unsafe / html href | 363.43 µs | 46.95 µs | 852.7 ns | 4.24 µs | 18.38 µs |
| mbt unsafe / html close | 680.82 µs | 101.97 µs | 25.76 µs | 7.82 µs | 51.95 µs |
| mbt unsafe / cjk word | 331.42 µs | 42.76 µs | 2.43 µs | 4.64 µs | 18.69 µs |
| mbt checked / ascii deep | 18.88 µs | 31.39 µs | 71.68 µs | 42.52 µs | 21.44 µs |
| mbt checked / ascii dense | 30.8 ns | 47.0 ns | 27.2 ns | 40.4 ns | 12.2 ns |
| mbt checked / html | 29.1 ns | 43.2 ns | 6.5 ns | 21.3 ns | 7.4 ns |
| mbt checked / cjk | 12.75 µs | 21.12 µs | 49.21 µs | 29.19 µs | 14.30 µs |
| mbt checked / mixed | 18.81 µs | 31.06 µs | 82.51 µs | 44.19 µs | 21.63 µs |
| mbt checked / no match | 24.33 µs | 41.52 µs | 108.59 µs | 57.87 µs | 28.59 µs |
| mbt checked / html href | 338.42 µs | 47.55 µs | 924.5 ns | 4.70 µs | 18.44 µs |
| mbt checked / html close | 636.60 µs | 98.90 µs | 28.78 µs | 7.62 µs | 52.12 µs |
| mbt checked / cjk word | 350.37 µs | 42.97 µs | 2.45 µs | 4.16 µs | 20.36 µs |

### macos-latest（llvm：nightly 工具链；其余：latest）

| 用例 | native | llvm | js | wasm | wasm-gc |
| --- | ---: | ---: | ---: | ---: | ---: |
| core / ascii deep | 5.19 µs | 21.88 µs | 1.28 µs | 7.96 µs | 31.68 µs |
| core / ascii dense | 15.2 ns | 18.0 ns | 19.5 ns | 35.9 ns | 23.5 ns |
| core / html | 15.6 ns | 10.9 ns | 16.8 ns | 33.0 ns | 16.2 ns |
| core / cjk | 3.20 µs | 14.91 µs | 3.54 µs | 5.01 µs | 22.53 µs |
| core / mixed | 4.40 µs | 30.13 µs | 111.40 µs | 7.62 µs | 32.19 µs |
| core / no match | 7.96 µs | 31.73 µs | 1.71 µs | 8.95 µs | 38.99 µs |
| core / html href | 4.19 µs | 48.77 µs | 916.0 ns | 6.16 µs | 27.15 µs |
| core / html close | 7.60 µs | 73.00 µs | 39.38 µs | 12.22 µs | 54.09 µs |
| core / cjk word | 4.43 µs | 33.47 µs | 4.27 µs | 7.85 µs | 25.73 µs |
| mbt unsafe / ascii deep | 23.21 µs | 17.89 µs | 170.02 µs | 37.61 µs | 30.99 µs |
| mbt unsafe / ascii dense | 18.9 ns | 15.0 ns | 19.6 ns | 40.4 ns | 17.1 ns |
| mbt unsafe / html | 10.2 ns | 10.7 ns | 9.7 ns | 46.4 ns | 9.9 ns |
| mbt unsafe / cjk | 15.28 µs | 13.52 µs | 102.75 µs | 25.34 µs | 20.40 µs |
| mbt unsafe / mixed | 24.86 µs | 19.68 µs | 157.29 µs | 37.34 µs | 29.85 µs |
| mbt unsafe / no match | 37.67 µs | 28.21 µs | 228.80 µs | 57.79 µs | 39.82 µs |
| mbt unsafe / html href | 5.51 µs | 35.31 µs | 891.0 ns | 7.48 µs | 24.53 µs |
| mbt unsafe / html close | 9.21 µs | 49.84 µs | 38.24 µs | 13.70 µs | 58.74 µs |
| mbt unsafe / cjk word | 5.33 µs | 30.22 µs | 3.69 µs | 7.53 µs | 26.16 µs |
| mbt checked / ascii deep | 35.81 µs | 19.52 µs | 163.55 µs | 76.64 µs | 30.51 µs |
| mbt checked / ascii dense | 18.5 ns | 14.2 ns | 26.6 ns | 47.8 ns | 15.2 ns |
| mbt checked / html | 11.1 ns | 9.1 ns | 9.1 ns | 31.2 ns | 7.6 ns |
| mbt checked / cjk | 20.87 µs | 13.83 µs | 125.42 µs | 41.25 µs | 20.03 µs |
| mbt checked / mixed | 28.06 µs | 17.34 µs | 187.12 µs | 61.20 µs | 31.36 µs |
| mbt checked / no match | 38.24 µs | 26.38 µs | 227.69 µs | 82.31 µs | 38.74 µs |
| mbt checked / html href | 3.65 µs | 35.77 µs | 885.8 ns | 6.62 µs | 25.40 µs |
| mbt checked / html close | 8.89 µs | 90.38 µs | 36.82 µs | 11.76 µs | 51.50 µs |
| mbt checked / cjk word | 4.33 µs | 31.37 µs | 3.82 µs | 6.50 µs | 26.21 µs |


## 许可证

MIT
