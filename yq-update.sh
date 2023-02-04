#!/bin/sh

# Description: Download, verify and install yq on Linux and Mac
# Author: Chuck Nemeth
# https://github.com/mikefarah/yq

bin_dir="$HOME/.local/bin"
man_dir="$HOME/.local/share/man/man1"
tmp_dir="$(mktemp -d /tmp/yq.XXXXXXXX)"

yq_installed_version="$(yq --version | cut -d' ' -f 4)"
yq_version="$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | \
              awk -F': ' '/tag_name/ { gsub(/\"|\,/,"",$2); print $2 }')"
yq_url="https://github.com/mikefarah/yq/releases/download/${yq_version}/"
yq_man="yq.1"

# Define clean_up function
clean_up () {
  printf "Would you like to delete the tmp_dir and the downloaded files? (Yy/Nn) "
  read -r choice
  case "${choice}" in
    [yY]|[yY]es)
      printf '%s\n\n' "Cleaning up install files"
      cd && rm -rf "${tmp_dir}"
      exit "${1}"
      ;;
    *)
      printf '%s\n\n' "Exiting without deleting files from ${tmp_dir}"
      exit "${1}"
      ;;
  esac
}

#######################
# OS CHECK
#######################
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
    tput setaf 1
    printf '%s\n' "[ERROR] Unsupported OS. Exiting"
    tpug sgr0
    clean_up 1
esac


#######################
# PATH CHECK
#######################
case :$PATH: in
  *:"${bin_dir}":*)  ;;  # do nothing
  *)
    tput setaf 1
    printf '%s\n' "[ERROR] ${bin_dir} was not found in \$PATH!"
    printf '%s\n\n' "[ERROR] Add ${bin_dir} to PATH or select another directory to install to"
    tput sgr0
    clean_up 1
    ;;
esac


#######################
# VERSION CHECK
#######################
cd "${tmp_dir}" || exit

if [ "${yq_version}" = "${yq_installed_version}" ]; then
  tput setaf 3
  printf '%s\n\n' "[WARN] Already using latest version. Exiting."
  tput sgr0
  clean_up 0
else
  printf '%s\n' "Installed Verision: ${yq_installed_version}"
  printf '%s\n' "Latest Version: ${yq_version}"
fi


#######################
# DOWNLOAD
#######################
printf '%s\n' "Downloading yq archive and verification files"
curl -sL -o "${tmp_dir}/${yq_archive}.tar.gz" "${yq_url}/${yq_archive}.tar.gz"
curl -sL -o "${tmp_dir}/checksums" "${yq_url}/checksums"
curl -sL -o "${tmp_dir}/checksums_hashes_order" "${yq_url}/checksums_hashes_order"

printf '%s\n\n' "Extracting ${yq_archive}.tar.gz"
tar -xf "${yq_archive}.tar.gz"


#######################
# VERIFY
#######################
grepMatch=$(grep -m 1 -n "SHA-512" checksums_hashes_order)
lineNumber=$(echo "$grepMatch" | cut -d: -f1)
realLineNumber="$((lineNumber + 1))"

awk -v ref="${yq_archive}.tar.gz" -v lin="$realLineNumber" \
  'match($1, ref) { print $lin "  " $1}' checksums > "${tmp_dir}/SHA512sums"

if ! shasum -qc "${tmp_dir}/SHA512sums"; then
  tput setaf 1
  printf '\n%s\n\n' "[ERROR] Problem with checksum!"
  tput sgr0
  clean_up 1
fi


#######################
# PREPARE
#######################
# Bin dir
if [ ! -d "${bin_dir}" ]; then
  mkdir -p "${bin_dir}"
fi

# Man dir
if [ ! -d "${man_dir}" ]; then
  mkdir -p "${man_dir}"
fi


#######################
# INSTALL
#######################
# Install binary
if [ -f "${tmp_dir}/${yq_archive}" ]; then
  mv "${tmp_dir}/${yq_archive}" "${bin_dir}/yq"
  chmod 700 "${bin_dir}/yq"
fi

# Install man page
if [ -f "${tmp_dir}/${yq_man}" ]; then
  mv "${tmp_dir}/${yq_man}" "${man_dir}/${yq_man}"
  chmod 640 "${man_dir}/${yq_man}"
fi


#######################
# VERSION CHECK
#######################
tput setaf 2
printf '\n%s\n' "Old Version: ${yq_installed_version}"
printf '%s\n\n' "Installed Version: $(yq --version | cut -d' ' -f 4)"
tput sgr0


#######################
# CLEAN UP
#######################
clean_up 0

# vim: ft=sh ts=2 sts=2 sw=2 sr et