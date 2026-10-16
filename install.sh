#!/usr/bin/env sh
# install.sh — Official POSIX bootstrapper for NumKit
set -eu

PREFIX="${NUMKIT_PREFIX:-$HOME/.numkit}"
WITH_SIMD="ON"
ALL_TOOLBOXES=0
JOBS=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --no-simd)
            WITH_SIMD="OFF"
            shift
            ;;
        --all-toolboxes)
            ALL_TOOLBOXES=1
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

echo "==> NumKit Installer"
echo "    Prefix: $PREFIX"
echo "    SIMD:   $WITH_SIMD"
echo "    Jobs:   $JOBS"

for tool in git cmake; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: required tool '$tool' not found in PATH." >&2
        exit 1
    fi
done

SRC_DIR="$PREFIX/src"
BIN_DIR="$PREFIX/bin"
MOD_DIR="$PREFIX/modules"
mkdir -p "$SRC_DIR" "$BIN_DIR" "$MOD_DIR"

clone_or_update() {
    repo="$1"
    target="$SRC_DIR/$repo"
    if [ -d "$target/.git" ]; then
        echo "==> Updating numkit/$repo..."
        git -C "$target" pull --ff-only origin main
    else
        echo "==> Cloning numkit/$repo..."
        git clone --depth 1 "https://github.com/numkit/$repo.git" "$target"
    fi
}

for repo in value sys ops numkit; do
    clone_or_update "$repo"
done

echo "==> Configuring and building numkit core..."
cmake -S "$SRC_DIR/numkit" -B "$SRC_DIR/numkit/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DNUMKIT_WITH_SIMD="$WITH_SIMD"
cmake --build "$SRC_DIR/numkit/build" --config Release --parallel "$JOBS"

cp "$SRC_DIR/numkit/build/numkit" "$BIN_DIR/numkit"
if [ -f "$SRC_DIR/numkit/build/numkit_codegen" ]; then
    cp "$SRC_DIR/numkit/build/numkit_codegen" "$BIN_DIR/numkit_codegen"
fi

if [ "$ALL_TOOLBOXES" -eq 1 ]; then
    for tb in signal wavelet stats control audio comm image; do
        clone_or_update "$tb"
        echo "==> Building toolbox numkit/$tb..."
        cmake -S "$SRC_DIR/$tb" -B "$SRC_DIR/$tb/build" \
            -DCMAKE_BUILD_TYPE=Release \
            -DNUMKIT_WITH_SIMD="$WITH_SIMD"
        cmake --build "$SRC_DIR/$tb/build" --config Release --parallel "$JOBS"
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
echo "    Add to your PATH:"
echo "      export PATH=\"$BIN_DIR:\$PATH\""
