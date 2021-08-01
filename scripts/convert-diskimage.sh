#!/usr/bin/env bash


# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
set -o errexit
set -o nounset
set -o pipefail

set -x

trap cleanup EXIT

# -----------------------------------------------------------------------------
# Global
# -----------------------------------------------------------------------------
declare -r VERSION=0.6.0
declare -r SCRIPT=${0##*/}
declare -r BASE_DIR=$(readlink -f $(dirname ${0})/..)
declare -r IMAGES_DIR=${BASE_DIR}/images
declare -r WORK_DIR="${IMAGES_DIR}/work-$$"
declare -g IMAGE_PATH=${IMAGE_PATH:-}
declare -g FORMAT="${FORMAT:-}"
declare -a FORMATS=()
declare -g DIST_NAME=${DIST_NAME:-}
declare -g TARGET=${TARGET:-server}
declare -g FIRMWARE=${FIRMWARE:-efi}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function usage() {
  local exit_code=${1:-1}
  cat << USAGE

  Usage:
    ${SCRIPT} -f <target-format> -n <image-name> -t <target>

  Options:
    -h | --help             This message
    -f | --format <format>  Convert qcow2 to other disk format.
                            Can be issued multiple times.
                            Supported formats are:
                            * vmdk (vmware)
                            * ova  (vmware, virtualbox et al)
                            * vhd  (azure, hyper-v)
                            * vhdx (azure, hyper-v)
                            * gcp  (google cloud platform)
    -n | --name <name>      Name of the image e.g. ubuntu-20.04
    -p | --path <sourceimg> Path to the source image.
    -t | --target <target>  Target suffice e.g. server
    -F | --firmware <fw>    Firmware of disk image. Either bios or efi.

USAGE
  exit ${exit_code}
}

function parse_options() {
  while (( ${#} > 0 )); do
    case ${1} in
    -t|--target)   shift; TARGET=${1};;
    -n|--name)     shift; DIST_NAME=${1};;
    -f|--format)   shift; FORMATS+=( "${1}" );;
    -F|--firmware) shift; FIRMWARE=${1};;
    -p|--path)     shift; IMAGE_PATH="${1}";;
    -h|--help)     usage 0;;
    esac
    shift
  done
}

function evaluate_options() {
  # convert the format to an array for
  FORMATS+=( ${FORMAT} )
}

function image_type() {
  local path=${1}; shift;
  [[ -f ${path} ]] || echo "unknown"
  case $(file ${path}) in
  *QCOW2*)   echo qcow2;;
  *DOS/MBR*) echo raw;;
  *)         echo "unknown";;
  esac
}


function image_out() {
  local extension=${1} shift;
  echo "${IMAGES_DIR}/${DIST_NAME}-${TARGET}-${FIRMWARE}.${extension}"
}

function find_image() {
  local dist_name=${1}; shift;
  if [[ -n ${IMAGE_PATH} && -f ${IMAGE_PATH} ]]; then
    echo ${IMAGE_PATH}
    return
  fi
  find ${IMAGES_DIR} -name "${dist_name}-${TARGET}.qcow2"
}

function to_raw_image() {
  local img_in="${1}"; shift;
  local img_raw="${1:-${img_in%.*}.raw}"
  qemu-img convert -f qcow2 -O raw "${img_in}" "${img_raw}"
}

function disk_size() {
  local image=${1}; shift;
  qemu-img info -f raw --output json "${image}" | jq '."virtual-size"'
}

function calc_size() {
  local image=${1}; shift;
  local mb=$(( 1024 * 1024 ))
  local size=$(disk_size "${image}")
  local rounded_size=$(( (${size}/${mb} + 1) * ${mb} ))
  if (( $((${size} % ${mb} )) == 0 )); then
    echo ${size}
  else
   echo ${rounded_size}
  fi
}

function align_image() {
  local raw_image="${1}"; shift;
  local rounded_size="$(calc_size "${raw_image}")"
  qemu-img resize -f raw "${raw_image}" ${rounded_size}
}

function convert_disk() {
  local method=${1}; shift;
  local img_in=${1}; shift;
  local img_out=${1}; shift;
  local options=${1}; shift;
  qemu-img convert \
    -f $(image_type ${img_in}) \
    ${options:+-o ${options}} \
    -O ${method} \
    "${img_in}" \
    "${img_out}"
}

function to_vhd() {
  local dist_name=${1}; shift;
  local img_in=$(find_image ${dist_name})
  local img_raw="${img_in%.*}.raw"
  local img_out="$(image_out vhd)"
  to_raw_image "${img_in}" "${img_raw}"
  align_image "${img_raw}"
  convert_disk vpc "${img_raw}" "${img_out}" subformat=fixed,force_size
  touch --reference "${img_in}" "${img_out}"
}

function to_vhdx() {
  local dist_name=${1}; shift;
  local img_in=$(find_image ${dist_name})
  local img_out="$(image_out vhdx)"
  convert_disk vhdx "${img_in}" "${img_out}" subformat=dynamic
}

function to_vmdk() {
  local dist_name=${1}; shift;
  local img_in=$(find_image ${dist_name})
  local img_out="$(image_out vmdk)"
  convert_disk vmdk "${img_in}" "${img_out}" \
    adapter_type=lsilogic,subformat=streamOptimized,compat6
  touch --reference "${img_in}" "${img_out}"
}

function to_ova() {
  local dist_name=${1}; shift;
  local img_in=$(find_image ${dist_name})
  local img_out="$(image_out ova)"
  local img_vmdk="$(image_out vmdk)"
  # create a vmdk first to include in the ova
  to_vmdk "${dist_name}"
  mkdir ${WORK_DIR}
  cp ${img_vmdk} ${WORK_DIR}/${dist_name}.vmdk
  ova::create_ovf ${WORK_DIR}/${dist_name}.vmdk
  ova::create_mf
  ova::create_archive ${img_out}
}

function ova::fetch_xml_template {
  sed '1,/^__XML_TEMPLATE__/d' $0
}

function ova::ovf_values {
  local disk=${1}; shift;
  local capacity;
  capacity=$(qemu-img info ${disk} | awk -F ': ' '/ virtual size:/{ print $2 }')
  declare -gA OVF_VALUES=(
    [OVF_DISK_FILE]=$(basename ${disk})
    [OVF_FIRMWARE]=${FIRMWARE}
    [OVF_BUILD_ID]=${RANDOM}
    [OVF_ID]=${DIST_NAME}-${TARGET}-${FIRMWARE}
    [OVF_NAME]=${DIST_NAME}
    [OVF_DISK_FILE_SIZE]=$(du -b ${disk} | awk '{ print $1 }')
    [OVF_DISK_CAPACITY_BYTES]=${capacity}
    [OVF_DISK_CAPACITY]=$(( ${capacity} / 1024 / 1024 / 1024 ))
  )
}

function ova::create_ovf {
  local disk=${1}; shift;
  local xml="$(ova::fetch_xml_template)"
  local ovf="${WORK_DIR}/${DIST_NAME}.ovf"
  echo "${xml}" > ${ovf}
  ova::ovf_values "${disk}"
  for key in "${!OVF_VALUES[@]}"; do
    sed -i "s/%${key}%/${OVF_VALUES[${key}]}/g" ${ovf}
  done
}

function ova::create_mf {
  (
    cd ${WORK_DIR}
    for file in *; do
       sha256sum $file | while read sum path; do
          echo "SHA256(${file}) = ${sum}"
       done
    done > ${DIST_NAME}.mf
  )
}

function ova::create_archive {
  local img_out=${1}; shift;
  [[ -f ${img_out} ]] && rm ${img_out}
  (
    cd ${WORK_DIR}
    tar \
      --format=ustar \
      -cf "${img_out}" \
      *.ovf *.mf *.vmdk
  )
}

function to_gcp() {
  local dist_name=${1}; shift;
  local img_in=$(find_image ${dist_name})
  local img_raw="${img_in%.*}.raw"
  local img_out="$(image_out tar.gz)"
  to_raw_image "${img_in}" "${img_raw}"
  align_image "${img_raw}"
  tar \
    --format=oldgnu \
    --sparse \
    --directory="${IMAGES_DIR}" \
    --transform="s|${img_raw##*/}|disk.raw|" \
    -czf "${img_out}" \
    "${img_raw##*/}"
  touch --reference "${img_in}" "${img_out}"
}

function convert_image() {
  for format in "${FORMATS[@]}"; do
    case ${format} in
    vmdk) to_vmdk "${DIST_NAME}";;
    ova)  to_ova  "${DIST_NAME}";;
    vhd)  to_vhd  "${DIST_NAME}";;
    vhdx) to_vhdx "${DIST_NAME}";;
    gcp)  to_gcp  "${DIST_NAME}";;
    *)    echo "Unknown disk format '${format}'"; usage 1;;
    esac
  done
}

function cleanup() {
  exit_code=$?
  find ${IMAGES_DIR} -name "${DIST_NAME}-${TARGET}.raw" -delete
  [[ -d ${WORK_DIR} ]] && rm -rf ${WORK_DIR}
  exit ${exit_code}
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
evaluate_options
convert_image ${DIST_NAME}

exit 0

__XML_TEMPLATE__
<?xml version="1.0" encoding="UTF-8"?>
<Envelope vmw:buildId="build-%OVF_BUILD_ID%" xmlns="http://schemas.dmtf.org/ovf/envelope/1" xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vmw="http://www.vmware.com/schema/ovf" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <References>
    <File ovf:href="%OVF_DISK_FILE%" ovf:id="file1" ovf:size="%OVF_DISK_FILE_SIZE%"/>
  </References>
  <DiskSection>
    <Info>Virtual disk information</Info>
    <Disk ovf:capacity="%OVF_DISK_CAPACITY%" ovf:capacityAllocationUnits="byte * 2^30" ovf:diskId="vmdisk1" ovf:fileRef="file1" ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized" ovf:populatedSize="%OVF_DISK_CAPACITY_BYTES%"/>
  </DiskSection>
  <NetworkSection>
    <Info>The list of logical networks</Info>
    <Network ovf:name="VM Network">
      <Description>The VM Network network</Description>
    </Network>
  </NetworkSection>
  <VirtualSystem ovf:id="%OVF_ID%">
    <Info>A virtual machine</Info>
    <Name>%OVF_NAME%</Name>
    <OperatingSystemSection ovf:id="101" vmw:osType="otherLinux64Guest">
      <Info>The kind of installed guest operating system</Info>
    </OperatingSystemSection>
    <VirtualHardwareSection>
      <Info>Virtual hardware requirements</Info>
      <System>
        <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
        <vssd:InstanceID>0</vssd:InstanceID>
        <vssd:VirtualSystemIdentifier>%OVF_NAME%</vssd:VirtualSystemIdentifier>
        <vssd:VirtualSystemType>vmx-08</vssd:VirtualSystemType>
      </System>
      <Item>
        <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
        <rasd:Description>Number of Virtual CPUs</rasd:Description>
        <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
        <rasd:Description>Memory Size</rasd:Description>
        <rasd:ElementName>2048MB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>2048</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:Address>0</rasd:Address>
        <rasd:Description>SCSI Controller</rasd:Description>
        <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
        <rasd:InstanceID>3</rasd:InstanceID>
        <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
        <rasd:ResourceType>6</rasd:ResourceType>
        <vmw:Config ovf:required="false" vmw:key="slotInfo.pciSlotNumber" vmw:value="16"/>
      </Item>
      <Item ovf:required="false">
        <rasd:Address>0</rasd:Address>
        <rasd:Description>USB Controller (EHCI)</rasd:Description>
        <rasd:ElementName>USB Controller</rasd:ElementName>
        <rasd:InstanceID>4</rasd:InstanceID>
        <rasd:ResourceSubType>vmware.usb.ehci</rasd:ResourceSubType>
        <rasd:ResourceType>23</rasd:ResourceType>
        <vmw:Config ovf:required="false" vmw:key="autoConnectDevices" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="ehciEnabled" vmw:value="true"/>
        <vmw:Config ovf:required="false" vmw:key="slotInfo.ehciPciSlotNumber" vmw:value="33"/>
        <vmw:Config ovf:required="false" vmw:key="slotInfo.pciSlotNumber" vmw:value="32"/>
      </Item>
      <Item>
        <rasd:Address>1</rasd:Address>
        <rasd:Description>IDE Controller</rasd:Description>
        <rasd:ElementName>VirtualIDEController 1</rasd:ElementName>
        <rasd:InstanceID>5</rasd:InstanceID>
        <rasd:ResourceType>5</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:Address>0</rasd:Address>
        <rasd:Description>IDE Controller</rasd:Description>
        <rasd:ElementName>VirtualIDEController 0</rasd:ElementName>
        <rasd:InstanceID>6</rasd:InstanceID>
        <rasd:ResourceType>5</rasd:ResourceType>
      </Item>
      <Item ovf:required="false">
        <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
        <rasd:ElementName>VirtualVideoCard</rasd:ElementName>
        <rasd:InstanceID>7</rasd:InstanceID>
        <rasd:ResourceType>24</rasd:ResourceType>
        <vmw:Config ovf:required="false" vmw:key="enable3DSupport" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="use3dRenderer" vmw:value="automatic"/>
        <vmw:Config ovf:required="false" vmw:key="useAutoDetect" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="videoRamSizeInKB" vmw:value="4096"/>
      </Item>
      <Item ovf:required="false">
        <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
        <rasd:ElementName>VirtualVMCIDevice</rasd:ElementName>
        <rasd:InstanceID>8</rasd:InstanceID>
        <rasd:ResourceSubType>vmware.vmci</rasd:ResourceSubType>
        <rasd:ResourceType>1</rasd:ResourceType>
        <vmw:Config ovf:required="false" vmw:key="allowUnrestrictedCommunication" vmw:value="false"/>
        <vmw:Config ovf:required="false" vmw:key="slotInfo.pciSlotNumber" vmw:value="34"/>
      </Item>
      <Item ovf:required="false">
        <rasd:AddressOnParent>0</rasd:AddressOnParent>
        <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
        <rasd:ElementName>CD-ROM 1</rasd:ElementName>
        <rasd:InstanceID>9</rasd:InstanceID>
        <rasd:Parent>6</rasd:Parent>
        <rasd:ResourceSubType>vmware.cdrom.atapi</rasd:ResourceSubType>
        <rasd:ResourceType>15</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:AddressOnParent>0</rasd:AddressOnParent>
        <rasd:ElementName>Hard Disk 1</rasd:ElementName>
        <rasd:HostResource>ovf:/disk/vmdisk1</rasd:HostResource>
        <rasd:InstanceID>10</rasd:InstanceID>
        <rasd:Parent>3</rasd:Parent>
        <rasd:ResourceType>17</rasd:ResourceType>
        <vmw:Config ovf:required="false" vmw:key="backing.writeThrough" vmw:value="false"/>
      </Item>
      <Item>
        <rasd:AddressOnParent>7</rasd:AddressOnParent>
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>VM Network</rasd:Connection>
        <rasd:Description>VmxNet3 ethernet adapter on &quot;VM Network&quot;</rasd:Description>
        <rasd:ElementName>Ethernet 1</rasd:ElementName>
        <rasd:InstanceID>11</rasd:InstanceID>
        <rasd:ResourceSubType>VmxNet3</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
        <vmw:Config ovf:required="false" vmw:key="slotInfo.pciSlotNumber" vmw:value="160"/>
        <vmw:Config ovf:required="false" vmw:key="wakeOnLanEnabled" vmw:value="false"/>
      </Item>
      <vmw:Config ovf:required="false" vmw:key="cpuHotAddEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="cpuHotRemoveEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="bootOptions.efiSecureBootEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="firmware" vmw:value="%OVF_FIRMWARE%"/>
      <vmw:Config ovf:required="false" vmw:key="virtualICH7MPresent" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="virtualSMCPresent" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="memoryHotAddEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="nestedHVEnabled" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="powerOpInfo.powerOffType" vmw:value="soft"/>
      <vmw:Config ovf:required="false" vmw:key="powerOpInfo.resetType" vmw:value="soft"/>
      <vmw:Config ovf:required="false" vmw:key="powerOpInfo.standbyAction" vmw:value="checkpoint"/>
      <vmw:Config ovf:required="false" vmw:key="powerOpInfo.suspendType" vmw:value="soft"/>
      <vmw:Config ovf:required="false" vmw:key="tools.afterPowerOn" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.afterResume" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.beforeGuestShutdown" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.beforeGuestStandby" vmw:value="true"/>
      <vmw:Config ovf:required="false" vmw:key="tools.syncTimeWithHost" vmw:value="false"/>
      <vmw:Config ovf:required="false" vmw:key="tools.toolsUpgradePolicy" vmw:value="manual"/>
      <vmw:ExtraConfig ovf:required="false" vmw:key="nvram" vmw:value="Ubuntu19.nvram"/>
    </VirtualHardwareSection>
    <AnnotationSection ovf:required="false">
      <Info>A human-readable annotation</Info>
      <Annotation>Generic OVF for loading disks into VMware</Annotation>
    </AnnotationSection>
  </VirtualSystem>
</Envelope>
