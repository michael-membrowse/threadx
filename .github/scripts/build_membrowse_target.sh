#!/usr/bin/env bash
# Build a Cortex-M sample ELF for MemBrowse memory analysis.
# Compiles libthreadx.a via the matching CMake toolchain, then links
# ports/<variant>/gnu/example_build/sample_threadx.{c,ld,...} into an ELF.
#
# Usage: build_membrowse_target.sh <variant>
#   variant: cortex_m0 | cortex_m3 | cortex_m4 | cortex_m7

set -euo pipefail

VARIANT="${1:?usage: $0 <cortex_m0|cortex_m3|cortex_m4|cortex_m7>}"
NUM="${VARIANT#cortex_m}"

# Use $PWD (set to repo root by the workflow / onboard-action's per-commit
# checkout) so the script works even when run from /tmp during onboarding,
# where $(dirname "$0")/../.. would resolve incorrectly.
REPO_ROOT="$(pwd)"
BUILD_DIR="${REPO_ROOT}/build-${VARIANT}"
EXAMPLE_DIR="${REPO_ROOT}/ports/${VARIANT}/gnu/example_build"

cd "${REPO_ROOT}"
rm -rf "${BUILD_DIR}"
cmake -B"${BUILD_DIR}" \
    -DCMAKE_TOOLCHAIN_FILE="${REPO_ROOT}/cmake/${VARIANT}.cmake" \
    -DCMAKE_BUILD_TYPE=Debug \
    -GNinja \
    "${REPO_ROOT}"
cmake --build "${BUILD_DIR}"

cd "${EXAMPLE_DIR}"
rm -f ./*.o sample_threadx.elf sample_threadx.map

CFLAGS="-g -O2 -mcpu=cortex-m${NUM} -mthumb"

arm-none-eabi-gcc -c ${CFLAGS} "cortexm${NUM}_vectors.S"
arm-none-eabi-gcc -c ${CFLAGS} "cortexm${NUM}_crt0.S"
arm-none-eabi-gcc -c ${CFLAGS} tx_initialize_low_level.S
arm-none-eabi-gcc -c ${CFLAGS} -I../../../../common/inc -I../inc sample_threadx.c

# Note: cortexm*_crt0.S references several symbols that sample_threadx.ld
# does not define (it was originally paired with a richer linker script).
# Define them as 0 so the runtime memory-copy loops become no-ops.
arm-none-eabi-gcc -g -mcpu=cortex-m${NUM} -mthumb \
    -T sample_threadx.ld -ereset_handler -nostartfiles \
    -o sample_threadx.elf -Wl,-Map=sample_threadx.map \
    -Wl,--defsym=__text_load_start__=0 \
    -Wl,--defsym=__text_start__=0 \
    -Wl,--defsym=__text_end__=0 \
    -Wl,--defsym=__fast_load_start__=0 \
    -Wl,--defsym=__fast_start__=0 \
    -Wl,--defsym=__fast_end__=0 \
    -Wl,--defsym=__ctors_load_start__=0 \
    -Wl,--defsym=__dtors_load_start__=0 \
    -Wl,--defsym=__rodata_load_start__=0 \
    -Wl,--defsym=__rodata_start__=0 \
    -Wl,--defsym=__rodata_end__=0 \
    "cortexm${NUM}_vectors.o" "cortexm${NUM}_crt0.o" \
    tx_initialize_low_level.o sample_threadx.o \
    "${BUILD_DIR}/libthreadx.a"

ls -la sample_threadx.elf sample_threadx.map
