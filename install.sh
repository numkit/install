#!/usr/bin/env sh
# install.sh — Official POSIX source bootstrapper for NumKit
set -eu

PREFIX="${NUMKIT_PREFIX:-$HOME/.numkit}"
VERSION_REF=""
FORCE_HEAD="${NUMKIT_HEAD:-0}"
WITH_SIMD="ON"
WITH_CODEGEN=1
ALL_TOOLBOXES=0
TOOLBOXES=""
USE_ZIG=0
JOBS=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --version)
            VERSION_REF="$2"
            shift 2
            ;;
        --head)
            FORCE_HEAD=1
            shift
            ;;
        --no-simd)
            WITH_SIMD="OFF"
            shift
            ;;
        --no-codegen)
            WITH_CODEGEN=0
            shift
            ;;
        --all-toolboxes)
            ALL_TOOLBOXES=1
            shift
            ;;
        --toolboxes)
            TOOLBOXES="$(echo "$2" | tr ',' ' ')"
            shift 2
            ;;
        --use-zig)
            USE_ZIG=1
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$JOBS" ]; then
    if command -v nproc >/dev/null 2>&1; then
        JOBS="$(nproc)"
    elif command -v sysctl >/dev/null 2>&1; then
        JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
    else
        JOBS=4
    fi
fi

SRC_DIR="$PREFIX/src"
BIN_DIR="$PREFIX/bin"
MOD_DIR="$PREFIX/modules"
TOOLCHAIN_DIR="$PREFIX/toolchain"
mkdir -p "$SRC_DIR" "$BIN_DIR" "$MOD_DIR" "$TOOLCHAIN_DIR"

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64) ZIG_ARCH="x86_64" ;;
    aarch64|arm64) ZIG_ARCH="aarch64" ;;
    *) ZIG_ARCH="$ARCH" ;;
esac

ensure_zig() {
    if [ -x "$TOOLCHAIN_DIR/zig/zig" ]; then
        echo "$TOOLCHAIN_DIR/zig/zig"
        return
    fi
    if command -v zig >/dev/null 2>&1; then
        command -v zig
        return
    fi

    ZIG_VER="0.13.0"
    case "$OS" in
        Linux)  ZIG_OS="linux" ;;
        Darwin) ZIG_OS="macos" ;;
        *)
            echo "Error: automatic Zig download unsupported on OS '$OS'." >&2
            exit 1
            ;;
    esac

    ZIG_PKG="zig-${ZIG_OS}-${ZIG_ARCH}-${ZIG_VER}"
    ZIG_URL="https://ziglang.org/download/${ZIG_VER}/${ZIG_PKG}.tar.xz"
    echo "==> Downloading portable Zig C++ toolchain ($ZIG_VER)..." >&2
    curl -fsSL "$ZIG_URL" -o "$TOOLCHAIN_DIR/${ZIG_PKG}.tar.xz"
    rm -rf "$TOOLCHAIN_DIR/zig_tmp" "$TOOLCHAIN_DIR/zig"
    mkdir -p "$TOOLCHAIN_DIR/zig_tmp"
    tar -xJf "$TOOLCHAIN_DIR/${ZIG_PKG}.tar.xz" -C "$TOOLCHAIN_DIR/zig_tmp"
    mv "$TOOLCHAIN_DIR/zig_tmp/${ZIG_PKG}" "$TOOLCHAIN_DIR/zig"
    rm -rf "$TOOLCHAIN_DIR/zig_tmp" "$TOOLCHAIN_DIR/${ZIG_PKG}.tar.xz"
    echo "$TOOLCHAIN_DIR/zig/zig"
}

ensure_cmake() {
    if [ -x "$TOOLCHAIN_DIR/cmake/bin/cmake" ]; then
        echo "$TOOLCHAIN_DIR/cmake/bin/cmake"
        return
    fi
    if [ -x "$TOOLCHAIN_DIR/cmake/CMake.app/Contents/bin/cmake" ]; then
        echo "$TOOLCHAIN_DIR/cmake/CMake.app/Contents/bin/cmake"
        return
    fi
    if command -v cmake >/dev/null 2>&1; then
        command -v cmake
        return
    fi

    CMAKE_VER="3.30.5"
    echo "==> Downloading portable CMake ($CMAKE_VER)..." >&2
    rm -rf "$TOOLCHAIN_DIR/cmake_tmp" "$TOOLCHAIN_DIR/cmake"
    mkdir -p "$TOOLCHAIN_DIR/cmake_tmp"
    if [ "$OS" = "Linux" ]; then
        CMAKE_PKG="cmake-${CMAKE_VER}-linux-${ZIG_ARCH}"
        CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/${CMAKE_PKG}.tar.gz"
        curl -fsSL "$CMAKE_URL" -o "$TOOLCHAIN_DIR/cmake.tar.gz"
        tar -xzf "$TOOLCHAIN_DIR/cmake.tar.gz" -C "$TOOLCHAIN_DIR/cmake_tmp"
        mv "$TOOLCHAIN_DIR/cmake_tmp/${CMAKE_PKG}" "$TOOLCHAIN_DIR/cmake"
        rm -rf "$TOOLCHAIN_DIR/cmake_tmp" "$TOOLCHAIN_DIR/cmake.tar.gz"
        echo "$TOOLCHAIN_DIR/cmake/bin/cmake"
    elif [ "$OS" = "Darwin" ]; then
        CMAKE_PKG="cmake-${CMAKE_VER}-macos-universal"
        CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/${CMAKE_PKG}.tar.gz"
        curl -fsSL "$CMAKE_URL" -o "$TOOLCHAIN_DIR/cmake.tar.gz"
        tar -xzf "$TOOLCHAIN_DIR/cmake.tar.gz" -C "$TOOLCHAIN_DIR/cmake_tmp"
        mv "$TOOLCHAIN_DIR/cmake_tmp/${CMAKE_PKG}" "$TOOLCHAIN_DIR/cmake"
        rm -rf "$TOOLCHAIN_DIR/cmake_tmp" "$TOOLCHAIN_DIR/cmake.tar.gz"
        echo "$TOOLCHAIN_DIR/cmake/CMake.app/Contents/bin/cmake"
    else
        echo "Error: 'cmake' not found in PATH." >&2
        exit 1
    fi
}

ensure_ninja() {
    if [ -x "$TOOLCHAIN_DIR/ninja/ninja" ]; then
        echo "$TOOLCHAIN_DIR/ninja/ninja"
        return
    fi
    if command -v ninja >/dev/null 2>&1; then
        command -v ninja
        return
    fi
    NINJA_VER="1.12.1"
    case "$OS" in
        Linux)  NINJA_ZIP="ninja-linux.zip" ;;
        Darwin) NINJA_ZIP="ninja-mac.zip" ;;
        *)      echo ""; return ;;
    esac
    echo "==> Downloading portable Ninja ($NINJA_VER)..." >&2
    mkdir -p "$TOOLCHAIN_DIR/ninja"
    curl -fsSL "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VER}/${NINJA_ZIP}" -o "$TOOLCHAIN_DIR/ninja.zip"
    unzip -qo "$TOOLCHAIN_DIR/ninja.zip" -d "$TOOLCHAIN_DIR/ninja"
    chmod +x "$TOOLCHAIN_DIR/ninja/ninja"
    rm -f "$TOOLCHAIN_DIR/ninja.zip"
    echo "$TOOLCHAIN_DIR/ninja/ninja"
}

if ! command -v git >/dev/null 2>&1; then
    echo "Error: required tool 'git' not found in PATH." >&2
    exit 1
fi

resolve_numkit_version() {
    if [ "$FORCE_HEAD" -eq 1 ]; then
        echo "main"
        return
    fi
    if [ -n "$VERSION_REF" ]; then
        echo "$VERSION_REF"
        return
    fi
    latest_tag="$(git ls-remote --tags --refs "https://github.com/numkit/numkit.git" 2>/dev/null \
        | sed -n 's|.*refs/tags/\(v[0-9][0-9]*\.[0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}\)$|\1|p' \
        | sort -V 2>/dev/null | tail -n 1 || true)"
    if [ -n "$latest_tag" ]; then
        echo "$latest_tag"
    else
        echo "main"
    fi
}

RESOLVED_REF="$(resolve_numkit_version)"
printf "%s" "$RESOLVED_REF" > "$PREFIX/VERSION"

CMAKE_BIN="$(ensure_cmake)"
ZIG_BIN="$(ensure_zig)"

if [ "$USE_ZIG" -eq 0 ] && ! command -v c++ >/dev/null 2>&1 && ! command -v g++ >/dev/null 2>&1 && ! command -v clang++ >/dev/null 2>&1; then
    USE_ZIG=1
fi

NINJA_BIN=""
if [ "$USE_ZIG" -eq 1 ]; then
    NINJA_BIN="$(ensure_ninja)"
fi

echo "==> NumKit Source Installer"
echo "    Prefix:  $PREFIX"
echo "    Version: $RESOLVED_REF"
echo "    CMake:   $CMAKE_BIN"
echo "    Zig C++: $ZIG_BIN"
echo "    SIMD:    $WITH_SIMD"
echo "    Jobs:    $JOBS"

clone_or_update() {
    repo="$1"
    target="$SRC_DIR/$repo"
    if [ -d "$target/.git" ]; then
        echo "==> Updating numkit/$repo ($RESOLVED_REF)..."
        git -C "$target" fetch --depth 1 origin "$RESOLVED_REF"
        git -C "$target" checkout --force FETCH_HEAD
    else
        echo "==> Cloning numkit/$repo ($RESOLVED_REF)..."
        git clone --depth 1 --branch "$RESOLVED_REF" "https://github.com/numkit/$repo.git" "$target"
    fi
}

cmake_build() {
    proj_src="$1"
    proj_build="$proj_src/build"
    if [ "$USE_ZIG" -eq 1 ] && [ ! -f "$proj_build/CMakeCache.txt" ] && [ -n "$NINJA_BIN" ]; then
        "$CMAKE_BIN" -Wno-deprecated -S "$proj_src" -B "$proj_build" \
            -G Ninja \
            -DCMAKE_MAKE_PROGRAM="$NINJA_BIN" \
            -DCMAKE_CXX_COMPILER="$ZIG_BIN" \
            -DCMAKE_CXX_COMPILER_ARG1="c++" \
            -DCMAKE_C_COMPILER="$ZIG_BIN" \
            -DCMAKE_C_COMPILER_ARG1="cc" \
            -DCMAKE_BUILD_TYPE=Release \
            -DNUMKIT_WITH_SIMD="$WITH_SIMD" \
            -DNUMKIT_BUILD_TESTS=OFF \
            -DNUMKIT_SYS_BUILD_TESTS=OFF
    else
        "$CMAKE_BIN" -Wno-deprecated -S "$proj_src" -B "$proj_build" \
            -DCMAKE_BUILD_TYPE=Release \
            -DNUMKIT_WITH_SIMD="$WITH_SIMD" \
            -DNUMKIT_BUILD_TESTS=OFF \
            -DNUMKIT_SYS_BUILD_TESTS=OFF
    fi
    "$CMAKE_BIN" --build "$proj_build" --config Release --parallel "$JOBS"
}

for repo in value sys ops numkit; do
    clone_or_update "$repo"
done
if [ "$WITH_CODEGEN" -eq 1 ]; then
    clone_or_update "codegen"
fi

echo "==> Building numkit/numkit runtime & CLI..."
cmake_build "$SRC_DIR/numkit"
cp "$SRC_DIR/numkit/build/numkit" "$BIN_DIR/numkit"

if [ "$WITH_CODEGEN" -eq 1 ]; then
    echo "==> Building numkit/codegen AOT transpiler..."
    cmake_build "$SRC_DIR/codegen"
    cp "$SRC_DIR/codegen/build/numkit-codegen" "$BIN_DIR/numkit-codegen"
    rm -f "$BIN_DIR/numkit_codegen"
fi

if [ "$ALL_TOOLBOXES" -eq 1 ]; then
    TOOLBOXES="signal wavelet stats control audio comm image"
fi

if [ -n "$TOOLBOXES" ]; then
    for tb in $TOOLBOXES; do
        clone_or_update "$tb"
        echo "==> Building toolbox numkit/$tb..."
        cmake_build "$SRC_DIR/$tb"
        mkdir -p "$MOD_DIR/$tb"
        cp "$SRC_DIR/$tb/manifest.json" "$MOD_DIR/$tb/manifest.json"
        for ext in so dylib; do
            if [ -f "$SRC_DIR/$tb/build/libnumkit_$tb.$ext" ]; then
                cp "$SRC_DIR/$tb/build/libnumkit_$tb.$ext" "$MOD_DIR/$tb/"
            elif [ -f "$SRC_DIR/$tb/build/numkit_$tb.$ext" ]; then
                cp "$SRC_DIR/$tb/build/numkit_$tb.$ext" "$MOD_DIR/$tb/"
            fi
        done
    done
fi

echo ""
echo "==> NumKit installed successfully to $BIN_DIR/numkit"
if [ "$WITH_CODEGEN" -eq 1 ]; then
    echo "==> AOT transpiler installed to $BIN_DIR/numkit-codegen (powered by Zig C++)"
fi
echo "    Add to your PATH:"
echo "      export PATH=\"$BIN_DIR:\$PATH\""
