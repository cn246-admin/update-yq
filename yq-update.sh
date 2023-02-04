#!/usr/bin/env bash

# Description: Install and verify yq
# Author: Chuck Nemeth
# https://github.com/mikefarah/yq

os="$(uname -s)"
bindir="$HOME/.local/bin"
mandir="$HOME/.local/share/man/man1"
tmpdir="$(mktemp -d /tmp/yq.XXXXXXXX)"
yq_man="yq.1"
yq_ver="$(yq --version | cut -d' ' -f 4)"
yq_url="https://github.com/mikefarah/yq/releases/latest/download/"


#######################
# OS CHECK
#######################
case "${os}" in
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
    printf '%s\n' "Unsupported OS. Exiting"
    exit 1
esac


#######################
# PATH CHECK
#######################
case :$PATH: in
  *:"${bindir}":*)  ;;  # do nothing
  *)
    printf '%s\n' "ERROR ${bindir} was not found in \$PATH!"
    printf '%s\n' "Add ${bindir} to PATH or select another directory to install to"
    exit 1
    ;;
esac


#######################
# VERSION CHECK
#######################
cd "${tmpdir}" || exit

printf '%s\n' "Downloading release_notes from yq GitHub"
curl -s -O https://raw.githubusercontent.com/mikefarah/yq/master/release_notes.txt

case "${os}" in
  "Darwin")
    available="$(< release_notes.txt grep '^\d' | head -n1)"
    ;;
  "Linux")
    available="$(< release_notes.txt grep -P '^\d' | head -n1)"
    ;;
esac

if [ "${available%%:}" = "${yq_ver##v}" ]; then
  printf '%s\n' "Already using latest version. Exiting."
  cd && rm -rf "${tmpdir}"
  exit
else
  printf '%s\n' "Installed Verision: ${yq_ver}"
  printf '%s\n' "Latest Version: ${available}"
fi


#######################
# DOWNLOAD
#######################
printf '%s\n' "Downloading yq archive"
curl -sL -o "${tmpdir}/${yq_archive}.tar.gz" "${yq_url}/${yq_archive}.tar.gz"
curl -sL -o "${tmpdir}/checksums" "${yq_url}/checksums"
curl -sL -o "${tmpdir}/checksums_hashes_order" "${yq_url}/checksums_hashes_order"

if [ -f "${yq_archive}.tar.gz" ]; then
  printf '%s\n' "Extracting ${yq_archive}.tar.gz"
  tar -xf "${yq_archive}.tar.gz"
else
  printf '%s\n' "Error ${yq_archive}.tar.gz not found! Did the download succeed?"
  exit 1
fi


#######################
# VERIFY
#######################
grepMatch=$(grep -m 1 -n "SHA-512" checksums_hashes_order)
lineNumber=$(echo "$grepMatch" | cut -d: -f1)
realLineNumber="$((lineNumber + 1))"

awk -v ref="${yq_archive}.tar.gz" -v lin="$realLineNumber" \
  'match($1, ref) { print $lin "  " $1}' checksums > "${tmpdir}/SHA512sums"

if ! shasum --algorithm=512 --check "${tmpdir}/SHA512sums"; then
  printf '%s\n' "Failed SHASUM check. Exiting"
  cd && rm -rf "${tmpdir}"
  exit 1
fi


#######################
# PREPARE
#######################
# Bin dir
if [ ! -d "${bindir}" ]; then
  mkdir -p "${bindir}"
fi

# Man dir
if [ ! -d "${mandir}" ]; then
  mkdir -p "${mandir}"
fi


#######################
# INSTALL
#######################
# Install binary
if [ -f "${tmpdir}/${yq_archive}" ]; then
  mv "${tmpdir}/${yq_archive}" "${bindir}/yq"
  chmod 700 "${bindir}/yq"
fi

# Install man page
if [ -f "${tmpdir}/${yq_man}" ]; then
  mv "${tmpdir}/${yq_man}" "${mandir}/${yq_man}"
  chmod 640 "${mandir}/${yq_man}"
fi


#######################
# VERSION CHECK
#######################
tput setaf 2
printf '\n%s\n' "Old Version: ${yq_ver}"
printf '%s\n\n' "Installed Version: $(yq --version | cut -d' ' -f 4)"
tput sgr0


#######################
# CLEAN UP
#######################
printf "Would you like to delete the install files? (Yy/Nn) "
read -r choice
case "${choice}" in
  [yY]|[yY]es)
    printf '%s\n\n' "Cleaning up install files"
    cd && rm -rf "${tmpdir}"
    ;;
  *)
    printf '%s\n\n' "Exiting without deleting files from ${tmpdir}"
    exit 0
    ;;
esac

# vim: ft=sh ts=2 sts=2 sw=2 sr et