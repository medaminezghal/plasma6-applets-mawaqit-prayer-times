#!/bin/sh
# Compile the widget's shaders (package/contents/shaders/*.frag) into the .qsb
# files Qt 6 loads. Needs qsb from Qt Shader Tools: qt6-shadertools on Arch,
# qt6-shader-baker on Debian/Ubuntu, or PySide6-Addons from pip (pyside6-qsb).
# Set QSB to choose the tool. Without the .qsb files the widget still works;
# the Horizon header then keeps a plain ink instead of its lighting.
#
# Every Qt that Plasma 6 runs on (6.6 and later) reads the .qsb format that
# current qsb writes. The same qsb version gives byte-identical files.
set -eu
cd "$(dirname "$0")"

if [ -z "${QSB:-}" ]; then
    for candidate in qsb /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb pyside6-qsb; do
        if command -v "$candidate" >/dev/null 2>&1; then
            QSB=$candidate
            break
        fi
    done
fi
if [ -z "${QSB:-}" ]; then
    echo "build-shaders.sh: qsb not found; install Qt Shader Tools or set QSB" >&2
    exit 1
fi

for src in package/contents/shaders/*.frag; do
    "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$src.qsb" "$src"
    echo "built $src.qsb"
done
