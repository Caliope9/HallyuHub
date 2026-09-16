#!/usr/bin/env bash
set -euo pipefail

flutter_version="3.44.0"
flutter_root="${TMPDIR:-/tmp}/flutter-sdk-${flutter_version}"
flutter_archive="${TMPDIR:-/tmp}/flutter-${flutter_version}-stable.tar.xz"
flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${flutter_version}-stable.tar.xz"

if [[ -z "${HALLYUHUB_SUPABASE_URL:-}" ]]; then
  echo "Missing HALLYUHUB_SUPABASE_URL in the Vercel build environment." >&2
  exit 1
fi

if [[ -z "${HALLYUHUB_SUPABASE_ANON_KEY:-}" ]]; then
  echo "Missing HALLYUHUB_SUPABASE_ANON_KEY in the Vercel build environment." >&2
  exit 1
fi

if [[ ! -x "${flutter_root}/bin/flutter" ]]; then
  rm -rf "${flutter_root}"
  curl --fail --silent --show-error --location "${flutter_url}" --output "${flutter_archive}"
  mkdir -p "${flutter_root}"
  tar -xJf "${flutter_archive}" --strip-components=1 -C "${flutter_root}"
fi

export PATH="${flutter_root}/bin:${PATH}"
git config --global --add safe.directory "${flutter_root}"

echo "Flutter ${flutter_version} ready."
flutter pub get
echo "Supabase production variables detected."
flutter build web --release \
  --dart-define="HALLYUHUB_SUPABASE_URL=${HALLYUHUB_SUPABASE_URL}" \
  --dart-define="HALLYUHUB_SUPABASE_ANON_KEY=${HALLYUHUB_SUPABASE_ANON_KEY}"
echo "Flutter web build completed at build/web."
