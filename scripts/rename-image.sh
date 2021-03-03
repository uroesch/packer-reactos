#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
set -o errexit
set -o nounset
set -o pipefail

# -----------------------------------------------------------------------------
# Global
# -----------------------------------------------------------------------------
declare -r VERSION=0.3.0
declare -r SCRIPT=${0##*/}
declare -r BASE_DIR=$(readlink -f $(dirname ${0})/..)
declare -r DEST_DIR=${BASE_DIR}/${DEST_DIR:-artifacts}
declare -r IMAGES_DIR=${BASE_DIR}/images
declare -g DIST_NAME=${DIST_NAME:-}
declare -g TARGET=${TARGET:-server}
declare -r PACKER_PREFIX='packer-'
declare -r DEBUG=${DEBUG:-false}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function init() {
  [[ ${DEBUG} == true ]] && set -x
  [[ ! -d ${IMAGES_DIR} ]] && mkdir -p ${IMAGES_DIR} || :
}

function image_type() {
  local path=${1}; shift;
  [[ -f ${path} ]] || echo "unknown"
  case $(file ${path}) in
  *QCOW2*) echo qcow2;;
  *) echo "Unknown";;
  esac
}

function find_image() {
  local dist_name=${1}; shift;
  find ${DEST_DIR} -regex ".*${TARGET}/${PACKER_PREFIX}${dist_name}.*"
}

function rename_image() {
  local dist_name=${1}; shift;
  local source_image=$(find_image ${dist_name})
  local source_dir=${source_image%/*}
  local source_type=$(image_type ${source_image})
  local basename=${source_dir##*/}
  local dest_image=${basename}.${source_type}

  mv ${source_image} ${IMAGES_DIR}/${dest_image}
  rmdir ${source_dir} || :
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
init
rename_image ${DIST_NAME}
