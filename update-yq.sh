#!/bin/sh

# Description: Download, verify and install yq on Linux and Mac
# Author: Chuck Nemeth
# https://github.com/mikefarah/yq

#######################
# VARIABLES
#######################
bindir="$HOME/.local/bin"
mandir="$HOME/.local/share/man/man1"
tmpdir="$(mktemp -d /tmp/yq.XXXXXXXX)"

if command -v yq >/dev/null; then
  yq_installed_version="$(yq --version | cut -d' ' -f 4)"
else
  yq_installed_version="Not Installed"
fi

yq_version="$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | \
              awk -F': ' '/tag_name/ { gsub(/\"|\,/,"",$2); print $2 }')"
yq_url="https://github.com/mikefarah/yq/releases/download/${yq_version}/"
yq_man="yq.1"

#######################
# FUNCTIONS
#######################
# Define clean_up function
clean_up () {
  printf "Would you like to delete the tmpdir and the downloaded files? (Yy/Nn) "
  read -r choice
  case "${choice}" in
    [yY]|[yY]es)
      printf '%s\n\n' "Cleaning up install files"
      cd && rm -rf "${tmpdir}"
      exit "${1}"
      ;;
    *)
      printf '%s\n\n' "Exiting without deleting files from ${tmpdir}"
      exit "${1}"
      ;;
  esac
}

# green output
code_grn () {
  tput setaf 2
  printf '%s\n' "${1}"
  tput sgr0
}

# red output
code_red () {
  tput setaf 1
  printf '%s\n' "${1}"
  tput sgr0
}

# yellow output
code_yel () {
  tput setaf 3
  printf '%s\n' "${1}"
  tput sgr0
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
    code_red "[ERROR] Unsupported OS. Exiting"
    clean_up 1
esac


#######################
# PATH CHECK
#######################
case :$PATH: in
  *:"${bindir}":*)  ;;  # do nothing
  *)
    code_red "[ERROR] ${bindir} was not found in \$PATH!"
    code_red "[ERROR] Add ${bindir} to PATH or select another directory to install to"
    clean_up 1
    ;;
esac


#######################
# VERSION CHECK
#######################
cd "${tmpdir}" || exit

if [ "${yq_version}" = "${yq_installed_version}" ]; then
  code_yel "[WARN] Already using latest version. Exiting."
  clean_up 0
else
  printf '%s\n' "Installed Verision: ${yq_installed_version}"
  printf '%s\n\n' "Latest Version: ${yq_version}"
fi


#######################
# DOWNLOAD
#######################
printf '%s\n' "Downloading yq archive and verification files"
curl -sL -o "${tmpdir}/${yq_archive}.tar.gz" "${yq_url}/${yq_archive}.tar.gz"
curl -sL -o "${tmpdir}/checksums" "${yq_url}/checksums"
curl -sL -o "${tmpdir}/checksums_hashes_order" "${yq_url}/checksums_hashes_order"

printf '%s\n' "Extracting ${yq_archive}.tar.gz"
tar -xf "${yq_archive}.tar.gz"


#######################
# VERIFY
#######################
grepMatch=$(grep -m 1 -n "SHA-512" checksums_hashes_order)
lineNumber=$(echo "$grepMatch" | cut -d: -f1)
realLineNumber="$((lineNumber + 1))"

awk -v ref="${yq_archive}.tar.gz" -v lin="$realLineNumber" \
  'match($1, ref) { print $lin "  " $1}' checksums > "${tmpdir}/SHA512sums"

printf '%s\n' "Verifying ${yq_archive}.tar.gz"
if ! shasum -qc "${tmpdir}/SHA512sums"; then
  code_red "[ERROR] Problem with checksum!"
  clean_up 1
fi


#######################
# PREPARE
#######################
# Create bin dir if it doesn't exist
if [ ! -d "${bindir}" ]; then
  mkdir -p "${bindir}"
fi

# Create man dir if it doesn't exist
if [ ! -d "${mandir}" ]; then
  mkdir -p "${mandir}"
fi


#######################
# INSTALL
#######################
# Install yq binary
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
code_grn "Done!"
code_grn "Installed Version: $(yq --version | cut -d' ' -f 4)"


#######################
# CLEAN UP
#######################
clean_up 0

# vim: ft=sh ts=2 sts=2 sw=2 sr et
