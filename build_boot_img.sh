#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

find_first_existing() {
	local path
	for path in "$@"; do
		if [[ -n "$path" && -f "$path" ]]; then
			printf '%s\n' "$path"
			return 0
		fi
	done
	return 1
}

usage() {
	cat <<EOF
Usage: $(basename "$0") [options] [-- <extra mkbootimg args>]

Builds boot.img using mkbootimg.
Defaults:
  kernel:  first of
           $REPO_ROOT/arch/arm64/boot/Image.gz
           $REPO_ROOT/arch/arm64/boot/Image
           $REPO_ROOT/out/arch/arm64/boot/Image.gz
           $REPO_ROOT/out/arch/arm64/boot/Image
           $REPO_ROOT/Image.gz
           $REPO_ROOT/Image
  dtb:     first of $REPO_ROOT/dtb, $REPO_ROOT/dtb.img
  ramdisk: first of $REPO_ROOT/ramdisk, $REPO_ROOT/ramdisk.img, $REPO_ROOT/ramdisk.cpio.gz
  output:  $REPO_ROOT/boot.img

Options:
  --kernel <path>    Kernel image path
  --dtb <path>       DTB image path
  --ramdisk <path>   Ramdisk image path
  --out <path>       Output boot image path
  --mkbootimg <bin>  mkbootimg binary/path (default: mkbootimg from PATH)
  -h, --help         Show this help
EOF
}

KERNEL_PATH=""
DTB_PATH=""
RAMDISK_PATH=""
OUT_PATH="$REPO_ROOT/boot.img"
MKBOOTIMG_BIN="mkbootimg"
EXTRA_ARGS=()

while (($#)); do
	case "$1" in
	--kernel)
		KERNEL_PATH="${2:-}"
		shift 2
		;;
	--dtb)
		DTB_PATH="${2:-}"
		shift 2
		;;
	--ramdisk)
		RAMDISK_PATH="${2:-}"
		shift 2
		;;
	--out)
		OUT_PATH="${2:-}"
		shift 2
		;;
	--mkbootimg)
		MKBOOTIMG_BIN="${2:-}"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		EXTRA_ARGS=("$@")
		break
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 1
		;;
	esac
done

if ! command -v "$MKBOOTIMG_BIN" >/dev/null 2>&1; then
	echo "mkbootimg not found: $MKBOOTIMG_BIN" >&2
	exit 1
fi

if [[ -z "$KERNEL_PATH" ]]; then
	KERNEL_PATH="$(find_first_existing \
		"$REPO_ROOT/arch/arm64/boot/Image.gz" \
		"$REPO_ROOT/arch/arm64/boot/Image" \
		"$REPO_ROOT/out/arch/arm64/boot/Image.gz" \
		"$REPO_ROOT/out/arch/arm64/boot/Image" \
		"$REPO_ROOT/Image.gz" \
		"$REPO_ROOT/Image")" || {
		echo "Kernel image not found. Use --kernel <path>." >&2
		exit 1
	}
fi

if [[ -z "$DTB_PATH" ]]; then
	DTB_PATH="$(find_first_existing "$REPO_ROOT/dtb" "$REPO_ROOT/dtb.img")" || {
		echo "DTB image not found in repo root. Use --dtb <path>." >&2
		exit 1
	}
fi

if [[ -z "$RAMDISK_PATH" ]]; then
	RAMDISK_PATH="$(find_first_existing \
		"$REPO_ROOT/ramdisk" \
		"$REPO_ROOT/ramdisk.img" \
		"$REPO_ROOT/ramdisk.cpio.gz")" || {
		echo "Ramdisk image not found in repo root. Use --ramdisk <path>." >&2
		exit 1
	}
fi

echo "Building boot image:"
echo "  kernel:  $KERNEL_PATH"
echo "  dtb:     $DTB_PATH"
echo "  ramdisk: $RAMDISK_PATH"
echo "  output:  $OUT_PATH"

"$MKBOOTIMG_BIN" \
	--kernel "$KERNEL_PATH" \
	--ramdisk "$RAMDISK_PATH" \
	--dtb "$DTB_PATH" \
	-o "$OUT_PATH" \
	"${EXTRA_ARGS[@]}"

echo "Created $OUT_PATH"
