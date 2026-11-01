# NumKit Installer (`numkit/install`)

Official cross-platform source bootstrapper for the **NumKit** scientific computing runtime, its **AOT C++17 transpiler (`numkit/codegen`)**, and official domain toolboxes.

Instead of shipping prebuilt binaries, `numkit/install` provisions a self-contained build environment in `~/.numkit/` (automatically fetching a portable **Zig C++17 toolchain**, **CMake**, and **Ninja** into `~/.numkit/toolchain/` when needed) and compiles NumKit natively for your CPU.

## Quick Install

### Linux & macOS
```sh
curl -fsSL https://raw.githubusercontent.com/numkit/install/main/install.sh | sh
```

With all official toolboxes (`signal`, `wavelet`, `control`, `audio`, `comm`, `image`, `stats`):
```sh
curl -fsSL https://raw.githubusercontent.com/numkit/install/main/install.sh | sh -s -- --all-toolboxes
```

### Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/numkit/install/main/install.ps1 | iex
```

Or run with options:
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/numkit/install/main/install.ps1))) -AllToolboxes
```

## Directory Layout (`~/.numkit/`)

- `~/.numkit/bin/` — compiled `numkit` CLI/REPL and `numkit_codegen` AOT transpiler
- `~/.numkit/toolchain/` — portable hermetic `zig` (`zig c++`), `cmake`, and `ninja`
- `~/.numkit/src/` — cloned source repositories (`value`, `sys`, `ops`, `numkit`, `codegen`, and installed toolboxes)
- `~/.numkit/modules/` — compiled shared toolbox plugins (`.dll` / `.so` / `.dylib`) and `manifest.json` descriptors

## Architecture & Repositories

NumKit is organized as a modular multi-repository ecosystem under [`github.com/numkit`](https://github.com/numkit):

| Repository | Layer | Description |
|---|---|---|
| [`numkit/value`](https://github.com/numkit/value) | Foundation (L0) | N-dimensional array container (`Value`), PMR memory arenas, type traits, `argcheck` |
| [`numkit/sys`](https://github.com/numkit/sys) | Foundation (L0) | Virtual filesystem (`FsContext`), toolchain discovery (`zig c++`, `msvc`, `clang`, `gcc`, `cmake`, `ninja`), process runner, `PluginContext` ABI |
| [`numkit/ops`](https://github.com/numkit/ops) | Compute (L1) | Engine-free SIMD kernels (Google Highway), BLAS, FFT, base math/array builtins, `linalg` decompositions/solvers, ODE/optim solvers, and `image_io` codecs |
| [`numkit/numkit`](https://github.com/numkit/numkit) | Core Engine (L2) | Parser, AST, TreeWalker, Bytecode VM, reactive engine (`ReactiveSession`), `graphics`/`io`/`help`, and `pkg` manager |
| [`numkit/codegen`](https://github.com/numkit/codegen) | Transpiler (L2) | Ahead-of-time (AOT) C++17 transpiler (`numkit_codegen`), static type inference, and C-ABI runtime bridge |
| [`numkit/signal`](https://github.com/numkit/signal) | Toolbox Plugin | Signal Processing Toolbox (`numkit_signal`) |
| [`numkit/wavelet`](https://github.com/numkit/wavelet) | Toolbox Plugin | Wavelet Toolbox (`numkit_wavelet`) |
| [`numkit/control`](https://github.com/numkit/control) | Toolbox Plugin | Control System Toolbox (`numkit_control`) |
| [`numkit/audio`](https://github.com/numkit/audio) | Toolbox Plugin | Audio Toolbox (`numkit_audio`) |
| [`numkit/comm`](https://github.com/numkit/comm) | Toolbox Plugin | Communications Toolbox (`numkit_comm`) |
| [`numkit/image`](https://github.com/numkit/image) | Toolbox Plugin | Image Processing Toolbox (`numkit_image`) |
| [`numkit/stats`](https://github.com/numkit/stats) | Toolbox Plugin | Statistics and Machine Learning Toolbox (`numkit_stats`) |

## Managing Toolboxes After Installation

Once `numkit` is installed, you can install or remove official or third-party toolboxes from source directly from the CLI or REPL:

```sh
numkit pkg install signal
numkit pkg install stats
numkit pkg list
```
