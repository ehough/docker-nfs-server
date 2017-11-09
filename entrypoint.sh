#!/usr/bin/env bash
#
# ehough/docker-nfs-server: A lightweight, robust, flexible, and containerized NFS server.
#
# Copyright (C) 2017  Eric D. Hough
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

readonly ENV_VAR_NFS_VERSION='NFS_VERSION'
readonly ENV_VAR_NFS_VERSION_DISABLE_V3='NFS_VERSION_DISABLE_V3'
readonly ENV_VAR_NFSD_SERVER_THREADS='NFSD_SERVER_THREADS'
readonly ENV_VAR_NFSD_PORT='NFSD_PORT'
readonly ENV_VAR_NFS_MOUNTD_PORT='NFS_MOUNTD_PORT'
readonly ENV_VAR_NFS_STATD_IN_PORT='NFS_STATD_IN_PORT'
readonly ENV_VAR_NFS_STATD_OUT_PORT='NFS_STATD_OUT_PORT'

readonly DEFAULT_NFS_VERSION='4.2'
readonly DEFAULT_NFSD_SERVER_THREADS="$(grep -Ec ^processor /proc/cpuinfo)"
readonly DEFAULT_NFSD_PORT=2049
readonly DEFAULT_NFS_MOUNTD_PORT=32767
readonly DEFAULT_NFS_STATD_IN_PORT=32765
readonly DEFAULT_NFS_STATD_OUT_PORT=32766


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

warn_on_failure() {

  if [[ $? -ne 0 ]]; then
    log "WARNING: $1"
  fi
}

exit_on_failure() {

  if [[ $? -ne 0 ]]; then
    log "$1"
    exit 1
  fi
}

######################################################################################
### teardown
######################################################################################

stop_process_if_running() {

  local -r pid=$(pidof "$1")

  if [[ -n $pid ]]; then
    log "killing $1"
    kill -TERM "$pid"
    warn_on_failure "unable to kill $1"
  else
    log "$1 was not running"
  fi
}

stop_unmount() {

  if mount | grep -Eq ^"$1 on $2\\s+"; then
    log "unmounting $1 from $2"
    umount "$2"
    warn_on_failure "unable to unmount $1 from $2"
  else
    log "$1 was not mounted on $2"
  fi
}

stop_nfsd() {

  log 'stopping nfsd'
  /usr/sbin/rpc.nfsd 0
  warn_on_failure 'unable to stop nfsd. if it had started already, check Docker host for lingering [nfsd] processes'
}

stop_exportfs() {

  log 'unexporting filesystems'
  /usr/sbin/exportfs -ua
  warn_on_failure 'unable to unexport filesystems'
}

stop() {

  logHeader 'terminating'

  stop_nfsd
  stop_process_if_running 'rpc.statd'
  stop_process_if_running 'rpc.mountd'
  stop_exportfs
  stop_process_if_running 'rpcbind'
  stop_unmount 'nfsd'       '/proc/fs/nfsd'
  stop_unmount 'rpc_pipefs' '/var/lib/nfs/rpc_pipefs'

  logHeader 'terminated'

  exit 0
}

stop_on_failure() {

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

   echo "${!ENV_VAR_NFSD_SERVER_THREADS:-$DEFAULT_NFSD_SERVER_THREADS}"
}

get_reqd_mountd_port() {

  echo "${!ENV_VAR_NFS_MOUNTD_PORT:-$DEFAULT_NFS_MOUNTD_PORT}"
}

get_reqd_nfsd_port() {

  echo "${!ENV_VAR_NFSD_PORT:-$DEFAULT_NFSD_PORT}"
}

get_reqd_statd_in_port() {

  echo "${!ENV_VAR_NFS_STATD_IN_PORT:-$DEFAULT_NFS_STATD_IN_PORT}"
}

get_reqd_statd_out_port() {

  echo "${!ENV_VAR_NFS_STATD_OUT_PORT:-$DEFAULT_NFS_STATD_OUT_PORT}"
}

is_nfs3_enabled() {

  if [[ -z "${!ENV_VAR_NFS_VERSION_DISABLE_V3}" ]]; then
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

assert_kernel_mod() {

  local -r moduleName=$1

  log "checking for presence of kernel module: $moduleName"

  lsmod | grep -Eq "^$moduleName\\s+"

  exit_on_failure "$moduleName module is not loaded on the Docker host's kernel (try: modprobe $moduleName)"
}

assert_port() {

  local -r envName=$1
  local -r value=${!envName}

  if [[ -n "$value" && ( "$value" -lt 1 || "$value" -gt 65535 ) ]]; then
    log "Please set $1 to a value between 1 and 65535 inclusive"
    exit 1
  fi
}

assert_nfs_version() {

  get_reqd_nfs_version | grep -Eq '^(3|4|4\.1|4\.2)$'
  exit_on_failure "please set $ENV_VAR_NFS_VERSION to 3, 4, 4.1, or 4.2"
}

assert_disabled_nfs3() {

  if [[ -z "$(is_nfs3_enabled)" && "$(get_reqd_nfs_version)" == '3' ]]; then
    log 'you cannot simultaneously enable and disable NFS version 3'
    exit 1
  fi
}

assert_nfsd_threads() {

  local -r requested=$(get_reqd_nfsd_threads)

  if [[ "$requested" -lt 1 ]]; then
    log "Please set $ENV_VAR_NFSD_SERVER_THREADS to a positive value"
    exit 1
  fi
}


######################################################################################
### initialization
######################################################################################

init_trap() {

  trap stop SIGTERM SIGINT
}

init_exports()
{
  if mount | grep -Eq '^[^ ]+ on /etc/exports type '; then
    log '/etc/exports appears to be mounted via Docker'
    return
  fi

  local collected=0
  local exports=''
  local candidateDirs

  candidateDirs=$(compgen -A variable | grep -E 'NFS_EXPORT_DIR_[0-9]*')
  exit_on_failure 'missing NFS_EXPORT_DIR_* environment variable(s)'

  log 'building /etc/exports'

  for dir in $candidateDirs; do

    local index=${dir##*_}
    local net=NFS_EXPORT_CLIENT_$index
    local opt=NFS_EXPORT_OPTIONS_$index

    if [[ ! -d "${!dir}" ]]; then
      log "skipping $dir (${!dir}) since it is not a directory"
      continue
    fi

    if [[ -n ${!net} ]] && [[ -n ${!opt} ]]; then

      log "will export ${!dir} to ${!net} with options ${!opt}"

      local line="${!dir} ${!net}(${!opt})"

      if [[ $collected -gt 0 ]]; then
        exports=$exports$'\n'
      fi

      exports=$exports$line

      (( collected++ ))

     else
        log "skipping $dir (${!dir}) as it is missing domain and/or options. be sure to set both $net and $opt."
     fi
  done

  if [[ $collected -eq 0 ]]; then
    log 'no directories to export.'
    exit 1
  fi

  log "will export $collected filesystem(s)"

  echo "$exports" > /etc/exports

  log '/etc/exports now contains the following contents:'
  cat /etc/exports
}

init_assertions() {

  # validate any user-supplied environment variables
  assert_port "$ENV_VAR_NFSD_PORT"
  assert_port "$ENV_VAR_NFS_MOUNTD_PORT"
  assert_port "$ENV_VAR_NFS_STATD_IN_PORT"
  assert_port "$ENV_VAR_NFS_STATD_OUT_PORT"
  assert_nfs_version
  assert_disabled_nfs3
  assert_nfsd_threads

  # check kernel modules
  assert_kernel_mod nfs
  assert_kernel_mod nfsd

  # ensure /etc/exports has at least one line
  grep -Evq '^\s*#|^\s*$' /etc/exports
  exit_on_failure '/etc/exports has no exports'

  # ensure we have CAP_SYS_ADMIN
  capsh --print | grep -Eq "^Current: = .*,?cap_sys_admin(,|$)"
  exit_on_failure 'missing CAP_SYS_ADMIN. be sure to run Docker with --cap-add SYS_ADMIN or --privileged'

  log 'requirements look good'
}


######################################################################################
### boot helpers
######################################################################################

boot_helper_do_mount() {

  local -r type=$1
  local -r path=$2
  local -r args=('-vt' "$type" "$path")

  log "mounting $type onto $path"
  mount "${args[@]}"
  stop_on_failure "unable to mount $type onto $path"
}

boot_helper_get_version_flags() {

  local versionFlags

  versionFlags=('--nfs-version' "$(get_reqd_nfs_version)" '--no-nfs-version' 2)

  if [[ -z "$(is_nfs3_enabled)" ]]; then
    versionFlags+=('--no-nfs-version' 3)
  fi

  echo "${versionFlags[@]}"
}


######################################################################################
### primary boot
######################################################################################

boot_main_mounts() {

  # http://wiki.linux-nfs.org/wiki/index.php/Nfsv4_configuration
  boot_helper_do_mount 'rpc_pipefs' '/var/lib/nfs/rpc_pipefs'
  boot_helper_do_mount 'nfsd'       '/proc/fs/nfsd'
}

boot_main_exportfs() {

  log 'exporting filesystems'
  /usr/sbin/exportfs -arv
  stop_on_failure 'exportfs failed'
}

boot_main_mountd() {

  local versionFlags
  IFS=' ' read -r -a versionFlags <<< "$(boot_helper_get_version_flags)"
  local -r port=$(get_reqd_mountd_port)
  local -r version=$(get_reqd_nfs_version)
  local -r args=('--debug' 'all' '--port' "$port" "${versionFlags[@]}")

  # yes, rpc.mountd is required even for NFS v4: https://forums.gentoo.org/viewtopic-p-7724856.html#7724856
  log "starting rpc.mountd for NFS version $version on port $port"
  /usr/sbin/rpc.mountd "${args[@]}"
  stop_on_failure 'rpc.mountd failed'
}

boot_main_rpcbind() {

  # rpcbind isn't required for NFSv4, but if it's not running then nfsd takes over 5 minutes to start up.
  # it's a bug in either nfs-utils on the kernel, and the code of both is over my head.
  # so as a workaround we start rpcbind now and (in v4-only scenarios) kill it after nfsd starts up
  log 'starting rpcbind'
  /sbin/rpcbind -ds
  stop_on_failure 'rpcbind failed'
}

boot_main_statd() {

  if [[ -z "$(is_nfs3_enabled)" ]]; then
    return
  fi

  local -r inPort=$(get_reqd_statd_in_port)
  local -r outPort=$(get_reqd_statd_out_port)
  local -r args=('--no-notify' '--port' "$inPort" '--outgoing-port' "$outPort")

  log "starting statd on port $inPort (outgoing connections on port $outPort)"
  /usr/sbin/rpc.statd "${args[@]}"
  stop_on_failure 'statd failed'
}

boot_main_nfsd() {

  local versionFlags
  IFS=' ' read -r -a versionFlags <<< "$(boot_helper_get_version_flags)"
  local -r threads=$(get_reqd_nfsd_threads)
  local -r port=$(get_reqd_nfsd_port)
  local -r version=$(get_reqd_nfs_version)
  local -r args=('--debug' 8 '--port' "$port" "${versionFlags[@]}" "$threads")

  log "starting rpc.nfsd on port $port with version $version and $threads server thread(s)"
  /usr/sbin/rpc.nfsd "${args[@]}"
  stop_on_failure 'rpc.nfsd failed'

  if [ -z "$(is_nfs3_enabled)" ]; then
    stop_process_if_running 'rpcbind'
  fi
}


######################################################################################
### main routines
######################################################################################

init() {

  logHeader 'setting up'
  init_trap
  init_exports
  init_assertions
}

boot() {

  logHeader 'starting services'
  boot_main_mounts
  boot_main_rpcbind
  boot_main_exportfs
  boot_main_mountd
  boot_main_statd
  boot_main_nfsd
}

hangout() {

  logHeader "server ready and waiting for connections on port $(get_reqd_nfsd_port)"

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
