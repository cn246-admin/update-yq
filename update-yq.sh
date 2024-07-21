#!/bin/sh

# Description: Download, verify and install yq on Linux and Mac
# Author: Chuck Nemeth
# https://github.com/mikefarah/yq

# OS CHECK
case "$(uname -s)" in
  "Darwin")
      case "$(uname -p)" in
        "arm")
          yq_archive="yq_darwin_arm64"
          ;;
        *)
          yq_archive="yq_darwin_amd64"
          ;;
      esac
    ;;
  "Linux")
    yq_archive="yq_linux_amd64"
    ;;
  *)
    code_red "[ERROR] Unsupported OS. Exiting"
    exit 1
esac

# VARIABLES
bin_dir="$HOME/.local/bin"
man_dir="$HOME/.local/share/man/man1"
tmp_dir="$(mktemp -d /tmp/yq.XXXXXXXX)"

if command -v yq >/dev/null; then
  yq_installed_version="$(yq --version | cut -d' ' -f 4)"
else
  yq_installed_version="Not Installed"
fi

yq_version="$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | \
              awk -F': ' '/tag_name/ { gsub(/\"|\,/,"",$2); print $2 }')"
yq_url="https://github.com/mikefarah/yq/releases/download/${yq_version}/"
yq_man="yq.1"

# Delete temporary install files
clean_up () {
  case "${1}" in
    [dD]|[dD]ebug)
      printf '%s\n' "[INFO] Exiting without deleting files from ${tmp_dir}"
      ;;
    *)
      printf '%s\n' "[INFO] Cleaning up install files"
      cd && rm -rf "${tmp_dir}"
      ;;
  esac
}

# Colored output
code_grn () { tput setaf 2; printf '%s\n' "${1}"; tput sgr0; }
code_red () { tput setaf 1; printf '%s\n' "${1}"; tput sgr0; }
code_yel () { tput setaf 3; printf '%s\n' "${1}"; tput sgr0; }

# PATH CHECK
case :$PATH: in
  *:"${bin_dir}":*)  ;;  # do nothing
  *)
    code_red "[ERROR] ${bin_dir} was not found in \$PATH!"
    code_red "Add ${bin_dir} to PATH or select another directory to install to"
    exit 1
    ;;
esac

# Run clean_up function on exit
trap clean_up EXIT

# Version Check
cd "${tmp_dir}" || exit

if [ "${yq_version}" = "${yq_installed_version}" ]; then
  printf '%s\n' "Installed Verision: ${yq_installed_version}"
  printf '%s\n' "Latest Version: ${yq_version}"
  code_yel "[INFO] Already using latest version. Exiting."
  exit
else
  printf '%s\n' "Installed Verision: ${yq_installed_version}"
  printf '%s\n' "Latest Version: ${yq_version}"
fi

# Download
printf '%s\n' "[INFO] Downloading yq archive and verification files"
curl -sL -o "${tmp_dir}/${yq_archive}.tar.gz" "${yq_url}/${yq_archive}.tar.gz"
curl -sL -o "${tmp_dir}/checksums" "${yq_url}/checksums"
curl -sL -o "${tmp_dir}/checksums_hashes_order" "${yq_url}/checksums_hashes_order"

printf '%s\n' "[INFO] Extracting ${yq_archive}.tar.gz"
tar -xf "${yq_archive}.tar.gz"

# Verify
grepMatch=$(grep -m 1 -n "SHA-512" checksums_hashes_order)
lineNumber=$(echo "$grepMatch" | cut -d: -f1)
realLineNumber="$((lineNumber + 1))"

awk -v ref="${yq_archive}.tar.gz" -v lin="$realLineNumber" \
  'match($1, ref) { print $lin "  " $1}' checksums > "${tmp_dir}/SHA512sums"

printf '%s\n' "[INFO] Verifying ${yq_archive}.tar.gz"
if ! shasum -qc "${tmp_dir}/SHA512sums"; then
  code_red "[ERROR] Problem with checksum!"
  exit 1
fi

# Create directories
[ ! -d "${bin_dir}" ] && install -m 0700 -d "${bin_dir}"
[ ! -d "${man_dir}" ] && install -m 0700 -d "${man_dir}"

# Install yq binary
if [ -f "${tmp_dir}/${yq_archive}" ]; then
  printf '%s\n' "[INFO] Installing yq binary"
  mv "${tmp_dir}/${yq_archive}" "${bin_dir}/yq"
  chmod 0700 "${bin_dir}/yq"
fi

# Install man page
if [ -f "${tmp_dir}/${yq_man}" ]; then
  printf '%s\n' "[INFO] Installing yq man page"
  mv "${tmp_dir}/${yq_man}" "${man_dir}/${yq_man}"
  chmod 0600 "${man_dir}/${yq_man}"
fi

# Version Ccheck
code_grn "[INFO] Done!"
code_grn "Installed Version: $(yq --version | cut -d' ' -f 4)"

# vim: ft=sh ts=2 sts=2 sw=2 sr et
