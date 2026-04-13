#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
qemu-riscv64 asm/hello
