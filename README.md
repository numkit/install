# NumKit Installer (`numkit/install`)

Official cross-platform bootstrapper and source installer for the **NumKit** scientific computing runtime and its official toolboxes.

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

## Architecture & Repositories

NumKit is organized as a modular multi-repository ecosystem under [`github.com/numkit`](https://github.com/numkit):

| Repository | Layer | Description |
|---|---|---|
| [`numkit/value`](https://github.com/numkit/value) | Foundation (L0) | N-dimensional array container (`Value`), PMR memory arenas, type traits, `argcheck` |
| [`numkit/sys`](https://github.com/numkit/sys) | Foundation (L0) | Virtual filesystem (`FsContext`), toolchain discovery (`msvc`, `clang`, `gcc`, `zig`), process runner, `PluginContext` ABI |
| [`numkit/ops`](https://github.com/numkit/ops) | Compute (L1) | Engine-free SIMD kernels (Google Highway), BLAS, 1D FFT, base math/array builtins, `linalg` decompositions/solvers, and `image_io` codecs |
| [`numkit/numkit`](https://github.com/numkit/numkit) | Core Engine (L2) | Parser, AST, TreeWalker, Bytecode VM, `linalg`/`ode`/`optim`/`io`/`graphics`/`help`, `scriptgraph`, `numkit_codegen`, and `pkg` manager |
| [`numkit/signal`](https://github.com/numkit/signal) | Toolbox Plugin | Signal Processing Toolbox (`numkit_signal`) |
| [`numkit/wavelet`](https://github.com/numkit/wavelet) | Toolbox Plugin | Wavelet Toolbox (`numkit_wavelet`) |
| [`numkit/control`](https://github.com/numkit/control) | Toolbox Plugin | Control System Toolbox (`numkit_control`) |
| [`numkit/audio`](https://github.com/numkit/audio) | Toolbox Plugin | Audio Toolbox (`numkit_audio`) |
| [`numkit/comm`](https://github.com/numkit/comm) | Toolbox Plugin | Communications Toolbox (`numkit_comm`) |
| [`numkit/image`](https://github.com/numkit/image) | Toolbox Plugin | Image Processing Toolbox (`numkit_image`) |
| [`numkit/stats`](https://github.com/numkit/stats) | Toolbox Plugin | Statistics and Machine Learning Toolbox (`numkit_stats`) |

## Managing Toolboxes After Installation

Once `numkit` is installed, you can install or remove official or third-party toolboxes directly from the CLI or REPL:

```sh
numkit -e "pkg install signal"
numkit -e "pkg install stats"
numkit -e "pkg list"
```
