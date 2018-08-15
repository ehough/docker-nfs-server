#!/usr/bin/env bash
#
# ehough/docker-nfs-server: A lightweight, robust, flexible, and containerized NFS server.
#
# Copyright (C) 2017-2018  Eric D. Hough
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

######################################################################################
### constants
######################################################################################

readonly ENV_VAR_NFS_DISABLE_VERSION_3='NFS_DISABLE_VERSION_3'
readonly ENV_VAR_NFS_SERVER_THREAD_COUNT='NFS_SERVER_THREAD_COUNT'
readonly ENV_VAR_NFS_ENABLE_KERBEROS='NFS_ENABLE_KERBEROS'
readonly ENV_VAR_NFS_PORT_MOUNTD='NFS_PORT_MOUNTD'
readonly ENV_VAR_NFS_PORT='NFS_PORT'
readonly ENV_VAR_NFS_PORT_STATD_IN='NFS_PORT_STATD_IN'
readonly ENV_VAR_NFS_PORT_STATD_OUT='NFS_PORT_STATD_OUT'
readonly ENV_VAR_NFS_VERSION='NFS_VERSION'

readonly DEFAULT_NFS_SERVER_THREAD_COUNT="$(grep -Ec ^processor /proc/cpuinfo)"
readonly DEFAULT_NFS_PORT=2049
readonly DEFAULT_NFS_PORT_MOUNTD=32767
readonly DEFAULT_NFS_PORT_STATD_IN=32765
readonly DEFAULT_NFS_PORT_STATD_OUT=32766
readonly DEFAULT_NFS_VERSION='4.2'

readonly PATH_BIN_EXPORTFS='/usr/sbin/exportfs'
readonly PATH_BIN_IDMAPD='/usr/sbin/rpc.idmapd'
readonly PATH_BIN_MOUNTD='/usr/sbin/rpc.mountd'
readonly PATH_BIN_NFSD='/usr/sbin/rpc.nfsd'
readonly PATH_BIN_RPCBIND='/sbin/rpcbind'
readonly PATH_BIN_RPC_SVCGSSD='/usr/sbin/rpc.svcgssd'
readonly PATH_BIN_STATD='/sbin/rpc.statd'

readonly PATH_FILE_ETC_EXPORTS='/etc/exports'
readonly PATH_FILE_ETC_IDMAPD_CONF='/etc/idmapd.conf'
readonly PATH_FILE_ETC_KRB5_CONF='/etc/krb5.conf'
readonly PATH_FILE_ETC_KRB5_KEYTAB='/etc/krb5.keytab'

readonly MOUNT_PATH_NFSD='/proc/fs/nfsd'
readonly MOUNT_PATH_RPC_PIPEFS='/var/lib/nfs/rpc_pipefs'


######################################################################################
### general purpose utilities
######################################################################################

log() {

  echo "----> $1"
}

logHeader() {

  echo ''
  echo '=================================================================='
  echo "      $1" | awk '{print toupper($0)}'
  echo '=================================================================='
}

bail() {

  log "ERROR: $1"
  exit 1
}

warn_on_failure() {

  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]]; then
    log "WARNING: $1"
  fi
}

exit_on_failure() {

  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]]; then
    bail "$1"
  fi
}

kill_process_if_running() {

  local -r base=$(basename "$1")
  local -r pid=$(pidof "$base")

  if [[ -n $pid ]]; then
    log "killing $base"
    kill -TERM "$pid"
    warn_on_failure "unable to kill $base"
  else
    log "$base was not running"
  fi
}


######################################################################################
### teardown
######################################################################################

stop_mount() {

  local -r path=$1
  local -r type=$(basename "$path")

  if mount | grep -Eq ^"$type on $path\\s+"; then
    log "un-mounting $type from $path"
    umount -v "$path"
    warn_on_failure "unable to un-mount $type from $path"
  else
    log "$type was not mounted on $path"
  fi
}

stop_nfsd() {

  log 'stopping nfsd'
  $PATH_BIN_NFSD 0
  warn_on_failure 'unable to stop nfsd. if it had started already, check Docker host for lingering [nfsd] processes'
}

stop_exportfs() {

  log 'un-exporting filesystems'
  $PATH_BIN_EXPORTFS -ua
  warn_on_failure 'unable to un-export filesystems'
}

stop() {

  logHeader 'terminating ...'

  kill_process_if_running "$PATH_BIN_RPC_SVCGSSD"
  stop_nfsd
  kill_process_if_running "$PATH_BIN_IDMAPD"
  kill_process_if_running "$PATH_BIN_STATD"
  kill_process_if_running "$PATH_BIN_MOUNTD"
  stop_exportfs
  kill_process_if_running "$PATH_BIN_RPCBIND"
  stop_mount "$MOUNT_PATH_NFSD"
  stop_mount "$MOUNT_PATH_RPC_PIPEFS"

  logHeader 'terminated'

  exit 0
}

stop_on_failure() {

  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]]; then
    log "$1"
    stop
  fi
}


######################################################################################
### runtime environment detection
######################################################################################

get_reqd_nfs_version() {

  echo "${!ENV_VAR_NFS_VERSION:-$DEFAULT_NFS_VERSION}"
}

get_reqd_nfsd_threads() {

   echo "${!ENV_VAR_NFS_SERVER_THREAD_COUNT:-$DEFAULT_NFS_SERVER_THREAD_COUNT}"
}

get_reqd_mountd_port() {

  echo "${!ENV_VAR_NFS_PORT_MOUNTD:-$DEFAULT_NFS_PORT_MOUNTD}"
}

get_reqd_nfsd_port() {

  echo "${!ENV_VAR_NFS_PORT:-$DEFAULT_NFS_PORT}"
}

get_reqd_statd_in_port() {

  echo "${!ENV_VAR_NFS_PORT_STATD_IN:-$DEFAULT_NFS_PORT_STATD_IN}"
}

get_reqd_statd_out_port() {

  echo "${!ENV_VAR_NFS_PORT_STATD_OUT:-$DEFAULT_NFS_PORT_STATD_OUT}"
}

is_kerberos_enabled() {

  if [[ -n "${!ENV_VAR_NFS_ENABLE_KERBEROS}" ]]; then
    echo 1
  fi
}

is_nfs3_enabled() {

  if [[ -z "${!ENV_VAR_NFS_DISABLE_VERSION_3}" ]]; then
    echo 1
  fi
}

is_nfs4_enabled() {

  if [[ "$(get_reqd_nfs_version)" =~ '^4' ]]; then
    echo 1
  fi
}


######################################################################################
### runtime configuration assertions
######################################################################################

assert_file_provided() {

  if [[ ! -f "$1" ]]; then
    bail "please provide $1 to the container"
  fi
}

assert_kernel_mod() {

  local -r moduleName=$1

  log "checking for presence of kernel module: $moduleName"

  lsmod | grep -Eq "^$moduleName\\s+" || [ -d "/sys/module/$moduleName" ]

  exit_on_failure "$moduleName module is not loaded on the Docker host's kernel (try: modprobe $moduleName)"
}

assert_port() {

  local -r envName=$1
  local -r value=${!envName}

  if [[ -n "$value" && ( "$value" -lt 1 || "$value" -gt 65535 ) ]]; then
    bail "please set $1 to a value between 1 and 65535 inclusive"
  fi
}

assert_nfs_version() {

  get_reqd_nfs_version | grep -Eq '^(3|4|4\.1|4\.2)$'
  exit_on_failure "please set $ENV_VAR_NFS_VERSION to 3, 4, 4.1, or 4.2"
}

assert_disabled_nfs3() {

  if [[ -z "$(is_nfs3_enabled)" && "$(get_reqd_nfs_version)" == '3' ]]; then
    bail 'you cannot simultaneously enable and disable NFS version 3'
  fi
}

assert_nfsd_threads() {

  local -r requested=$(get_reqd_nfsd_threads)

  if [[ "$requested" -lt 1 ]]; then
    bail "please set $ENV_VAR_NFS_SERVER_THREAD_COUNT to a positive value"
  fi
}

assert_kerberos_requirements() {

  if [[ -n "$(is_kerberos_enabled)" ]]; then

    assert_file_provided "$PATH_FILE_ETC_IDMAPD_CONF"
    assert_file_provided "$PATH_FILE_ETC_KRB5_KEYTAB"
    assert_file_provided "$PATH_FILE_ETC_KRB5_CONF"

    assert_kernel_mod rpcsec_gss_krb5
  fi
}


######################################################################################
### initialization
######################################################################################

init_trap() {

  trap stop SIGTERM SIGINT
}

init_exports() {

  # first, see if it's bind-mounted
  if mount | grep -Eq "^[^ ]+ on $PATH_FILE_ETC_EXPORTS type "; then
    log "$PATH_FILE_ETC_EXPORTS is bind-mounted"
    return
  fi

  # maybe it's baked-in to the image
  if [[ -f $PATH_FILE_ETC_EXPORTS && -r $PATH_FILE_ETC_EXPORTS && -s $PATH_FILE_ETC_EXPORTS ]]; then
    log "$PATH_FILE_ETC_EXPORTS is baked into the image"
    return
  fi

  local collected=0
  local exports=''
  local candidateExportVariables

  candidateExportVariables=$(compgen -A variable | grep -E 'NFS_EXPORT_[0-9]+' | sort)
  exit_on_failure "please provide $PATH_FILE_ETC_EXPORTS or set NFS_EXPORT_* environment variables"

  log "building $PATH_FILE_ETC_EXPORTS"

  for exportVariable in $candidateExportVariables; do

    local line=${!exportVariable}
    local lineAsArray
    read -r -a lineAsArray <<< "$line"
    local dir="${lineAsArray[0]}"

    if [[ ! -d "$dir" ]]; then
      log "skipping $line since $dir is not a directory"
      continue
    fi

    log "will export $line"

    if [[ $collected -gt 0 ]]; then
      exports=$exports$'\n'
    fi

    exports=$exports$line

    (( collected++ ))

  done

  if [[ $collected -eq 0 ]]; then
    bail 'no valid exports'
  fi

  log "will export $collected filesystem(s)"

  echo "$exports" > $PATH_FILE_ETC_EXPORTS
}

init_assertions() {

  # validate any user-supplied environment variables
  assert_port "$ENV_VAR_NFS_PORT"
  assert_port "$ENV_VAR_NFS_PORT_MOUNTD"
  assert_port "$ENV_VAR_NFS_PORT_STATD_IN"
  assert_port "$ENV_VAR_NFS_PORT_STATD_OUT"
  assert_nfs_version
  assert_disabled_nfs3
  assert_nfsd_threads

  # check kernel modules
  assert_kernel_mod nfs
  assert_kernel_mod nfsd

  # ensure /etc/exports has at least one line
  grep -Evq '^\s*#|^\s*$' $PATH_FILE_ETC_EXPORTS
  exit_on_failure "$PATH_FILE_ETC_EXPORTS has no exports"

  # ensure we have CAP_SYS_ADMIN
  capsh --print | grep -Eq "^Current: = .*,?cap_sys_admin(,|$)"
  exit_on_failure 'missing CAP_SYS_ADMIN. be sure to run Docker with --cap-add SYS_ADMIN or --privileged'

  # perform Kerberos assertions
  assert_kerberos_requirements
}


######################################################################################
### boot helpers
######################################################################################

boot_helper_mount() {

  local -r path=$1
  local -r type=$(basename "$path")
  local -r args=('-vt' "$type" "$path")

  log "mounting $type onto $path"
  mount "${args[@]}"
  stop_on_failure "unable to mount $type onto $path"
}

boot_helper_get_version_flags() {

  local versionFlags
  local -r requestedVersion="$(get_reqd_nfs_version)"

  versionFlags=('--nfs-version' "$requestedVersion" '--no-nfs-version' 2)

  if [[ -z "$(is_nfs3_enabled)" ]]; then
    versionFlags+=('--no-nfs-version' 3)
  fi

  if [[ "$requestedVersion" == '3' ]]; then
    versionFlags+=('--no-nfs-version' 4)
  fi

  echo "${versionFlags[@]}"
}


######################################################################################
### primary boot
######################################################################################

boot_main_mounts() {

  # http://wiki.linux-nfs.org/wiki/index.php/Nfsv4_configuration
  boot_helper_mount "$MOUNT_PATH_RPC_PIPEFS"
  boot_helper_mount "$MOUNT_PATH_NFSD"
}

boot_main_exportfs() {

  log 'exporting filesystems'
  $PATH_BIN_EXPORTFS -arv
  stop_on_failure 'exportfs failed'
}

boot_main_mountd() {

  local versionFlags
  read -r -a versionFlags <<< "$(boot_helper_get_version_flags)"
  local -r port=$(get_reqd_mountd_port)
  local -r version=$(get_reqd_nfs_version)
  local -r args=('--debug' 'all' '--port' "$port" "${versionFlags[@]}")

  # yes, rpc.mountd is required even for NFS v4: https://forums.gentoo.org/viewtopic-p-7724856.html#7724856
  log "starting rpc.mountd for NFS version $version on port $port"
  $PATH_BIN_MOUNTD "${args[@]}"
  stop_on_failure 'rpc.mountd failed'
}

boot_main_rpcbind() {

  # rpcbind isn't required for NFSv4, but if it's not running then nfsd takes over 5 minutes to start up.
  # it's a bug in either nfs-utils or the kernel, and the code of both is over my head.
  # so as a workaround we start rpcbind now and (in v4-only scenarios) kill it after nfsd starts up
  log 'starting rpcbind'
  $PATH_BIN_RPCBIND -ds
  stop_on_failure 'rpcbind failed'
}

boot_main_idmapd() {

  if [[ "$(get_reqd_nfs_version)" != '3' && -f "$PATH_FILE_ETC_IDMAPD_CONF" ]]; then
    log 'starting idmapd'
    $PATH_BIN_IDMAPD -v -S
    stop_on_failure 'idmapd failed'
  fi
}

boot_main_statd() {

  if [[ -z "$(is_nfs3_enabled)" ]]; then
    return
  fi

  local -r inPort=$(get_reqd_statd_in_port)
  local -r outPort=$(get_reqd_statd_out_port)
  local -r args=('--no-notify' '--port' "$inPort" '--outgoing-port' "$outPort")

  log "starting statd on port $inPort (outgoing connections on port $outPort)"
  $PATH_BIN_STATD "${args[@]}"
  stop_on_failure 'statd failed'
}

boot_main_nfsd() {

  local versionFlags
  read -r -a versionFlags <<< "$(boot_helper_get_version_flags)"
  local -r threads=$(get_reqd_nfsd_threads)
  local -r port=$(get_reqd_nfsd_port)
  local -r version=$(get_reqd_nfs_version)
  local -r args=('--debug' 8 '--port' "$port" "${versionFlags[@]}" "$threads")

  log "starting rpc.nfsd on port $port with version $version and $threads server thread(s)"
  $PATH_BIN_NFSD "${args[@]}"
  stop_on_failure 'rpc.nfsd failed'

  if [ -z "$(is_nfs3_enabled)" ]; then
    kill_process_if_running "$PATH_BIN_RPCBIND"
  fi
}

boot_main_svcgssd() {

  if [[ -z "$(is_kerberos_enabled)" ]]; then
    return
  fi

  log 'starting rpc.svcgssd'
  $PATH_BIN_RPC_SVCGSSD -f &
  stop_on_failure 'rpc.svcgssd failed'
}

boot_main_print_ready_message() {

  logHeader "ready and waiting for connections on port $(get_reqd_nfsd_port)"
  log 'list of exports:'
  cat $PATH_FILE_ETC_EXPORTS
}


######################################################################################
### main routines
######################################################################################

init() {

  logHeader 'setting up'

  init_trap
  init_exports
  init_assertions

  log 'setup complete'
}

boot() {

  logHeader 'starting services'

  boot_main_mounts
  boot_main_rpcbind
  boot_main_exportfs
  boot_main_mountd
  boot_main_statd
  boot_main_idmapd
  boot_main_nfsd
  boot_main_svcgssd
  boot_main_print_ready_message
}

hangout() {

  # wait forever or until we get SIGTERM or SIGINT
  # https://stackoverflow.com/a/41655546/229920
  # https://stackoverflow.com/a/27694965/229920
  while :; do sleep 2073600 & wait; done
}

main() {

  init
  boot
  hangout
}

main
