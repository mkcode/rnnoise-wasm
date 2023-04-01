#!/bin/bash

set -e

export OPTIMIZE="-Os"
export LDFLAGS=${OPTIMIZE}
export CFLAGS=${OPTIMIZE}
export CXXFLAGS=${OPTIMIZE}

ENTRY_POINT_WORKLET="rnnoise-worklet.js"
ENTRY_POINT_BROWSER="rnnoise.js"
MODULE_CREATE_NAME_WORKLET="createRNNWasmModuleWorklet"
MODULE_CREATE_NAME_BROWSER="createRNNWasmModule"
RNN_EXPORTED_FUNCTIONS="['_rnnoise_process_frame', '_rnnoise_init', '_rnnoise_destroy', '_rnnoise_create', '_malloc', '_free']"


if [[ `uname` == "Darwin"  ]]; then
  SO_SUFFIX="dylib"
else
  SO_SUFFIX="so"
fi

echo "============================================="
echo "Compiling wasm bindings"
echo "============================================="
(
  cd rnnoise

  # Clean possible autotools clutter that might affect the configurations step
  git clean -f -d
  ./autogen.sh

  # For some reason setting the CFLAGS export doesn't apply optimization to all compilation steps
  # so we need to explicitly pass it to configure.
  emconfigure ./configure CFLAGS=${OPTIMIZE} --enable-static=no --disable-examples --disable-doc
  emmake make clean
  emmake make V=1

  # Worklet is sync, inline the wasm, and no es6 import meta
  emcc \
    ${OPTIMIZE} \
    -g2 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s MALLOC=emmalloc \
    -s MODULARIZE=1 \
    -s ENVIRONMENT="web,worker" \
    -s EXPORT_ES6=1 \
    -s USE_ES6_IMPORT_META=0 \
    -s WASM_ASYNC_COMPILATION=0 \
    -s SINGLE_FILE=1 \
    -s EXPORT_NAME=${MODULE_CREATE_NAME_WORKLET} \
    -s EXPORTED_FUNCTIONS="${RNN_EXPORTED_FUNCTIONS}" \
    .libs/librnnoise.${SO_SUFFIX} \
    -o ./$ENTRY_POINT_WORKLET

  # Browser is async, inline the wasm, and yes es6 import meta
  emcc \
    ${OPTIMIZE} \
    -g2 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s MALLOC=emmalloc \
    -s MODULARIZE=1 \
    -s ENVIRONMENT="web,worker" \
    -s EXPORT_ES6=1 \
    -s USE_ES6_IMPORT_META=1 \
    -s WASM_ASYNC_COMPILATION=1 \
    -s SINGLE_FILE=1 \
    -s EXPORT_NAME=${MODULE_CREATE_NAME_BROWSER} \
    -s EXPORTED_FUNCTIONS="${RNN_EXPORTED_FUNCTIONS}" \
    .libs/librnnoise.${SO_SUFFIX} \
    -o ./$ENTRY_POINT_BROWSER

  # Create output folder
  rm -rf ../dist
  mkdir -p ../dist

  # Move artifacts
  mv $ENTRY_POINT_WORKLET ../dist/
  mv $ENTRY_POINT_BROWSER ../dist/

  # Clean cluttter
  git clean -f -d
)
echo "============================================="
echo "Compiling wasm bindings done"
echo "============================================="
