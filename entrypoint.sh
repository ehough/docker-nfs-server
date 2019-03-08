#!/usr/bin/env bash
#
# ehough/docker-nfs-server: A lightweight, robust, flexible, and containerized NFS server.
#
# https://hub.docker.com/r/erichough/nfs-server
# https://github.com/ehough/docker-nfs-server
#
# Copyright (C) 2017-2019  Eric D. Hough
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
readonly ENV_VAR_NFS_LOG_LEVEL='NFS_LOG_LEVEL'

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

readonly REGEX_EXPORTS_LINES_TO_SKIP='^\s*#|^\s*$'


######################################################################################
### logging
######################################################################################

log() {

  echo "----> $1"
}

log_warning() {

  log "WARNING: $1"
}

log_error() {

  log ''
  log "ERROR: $1"
  log ''
}

log_header() {

  echo "
==================================================================
      $(echo "$1" | awk '{print toupper($0)}')
=================================================================="
}


######################################################################################
### error handling
######################################################################################

bail() {

  log_error "$1"
  exit 1
}

on_failure() {

  # shellcheck disable=SC2181
  if [[ $? -eq 0 ]]; then
    return
  fi

  case "$1" in
    warn)
      log_warning "$2"
      ;;
    stop)
      log_error "$2"
      stop
      ;;
    *)
      bail "$2"
      ;;
  esac
}


######################################################################################
### process control
######################################################################################

kill_process_if_running() {

  local -r base=$(basename "$1")
  local -r pid=$(pidof "$base")

  if [[ -n $pid ]]; then
    log "killing $base"
    kill -TERM "$pid"
    on_failure warn "unable to kill $base"
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

    local args=()
    if is_debug_requested; then
      args+=('-v')
    fi
    args+=("$path")

    log "un-mounting $type filesystem from $path"
    umount "${args[@]}"
    on_failure warn "unable to un-mount $type filesystem from $path"

  else
    log "no active mount at $path"
  fi
}

stop_nfsd() {

  log 'stopping nfsd'
  $PATH_BIN_NFSD 0
  on_failure warn 'unable to stop nfsd. if it had started already, check Docker host for lingering [nfsd] processes'
}

stop_exportfs() {

  local args=('-ua')
  if is_debug_requested; then
    args+=('-v')
  fi

  log 'un-exporting filesystem(s)'
  $PATH_BIN_EXPORTFS "${args[@]}"
  on_failure warn 'unable to un-export filesystem(s)'
}

stop() {

  log_header 'terminating ...'

  if is_kerberos_requested; then
    kill_process_if_running "$PATH_BIN_RPC_SVCGSSD"
  fi

  stop_nfsd

  if is_idmapd_requested; then
    kill_process_if_running "$PATH_BIN_IDMAPD"
  fi

  if is_nfs3_enabled; then
    kill_process_if_running "$PATH_BIN_STATD"
  fi

  kill_process_if_running "$PATH_BIN_MOUNTD"
  stop_exportfs
  kill_process_if_running "$PATH_BIN_RPCBIND"
  stop_mount "$MOUNT_PATH_NFSD"
  stop_mount "$MOUNT_PATH_RPC_PIPEFS"

  log_header 'terminated'

  exit 0
}


######################################################################################
### runtime environment detection
######################################################################################

get_requested_nfs_version() {

  echo "${!ENV_VAR_NFS_VERSION:-$DEFAULT_NFS_VERSION}"
}

get_requested_port_mountd() {

  echo "${!ENV_VAR_NFS_PORT_MOUNTD:-$DEFAULT_NFS_PORT_MOUNTD}"
}

get_requested_port_nfsd() {

  echo "${!ENV_VAR_NFS_PORT:-$DEFAULT_NFS_PORT}"
}

get_requested_port_statd_in() {

  echo "${!ENV_VAR_NFS_PORT_STATD_IN:-$DEFAULT_NFS_PORT_STATD_IN}"
}

get_requested_port_statd_out() {

  echo "${!ENV_VAR_NFS_PORT_STATD_OUT:-$DEFAULT_NFS_PORT_STATD_OUT}"
}

is_kerberos_requested() {

  if [[ -n "${!ENV_VAR_NFS_ENABLE_KERBEROS}" ]]; then
    return 0
  fi

  return 1
}

is_nfs3_enabled() {

  if [[ -z "${!ENV_VAR_NFS_DISABLE_VERSION_3}" ]]; then
    return 0
  fi

  return 1
}

is_idmapd_requested() {

  if [[ -f "$PATH_FILE_ETC_IDMAPD_CONF" ]]; then
    return 0
  fi

  return 1
}

is_kernel_module_loaded() {

  local -r module=$1

  if lsmod | grep -Eq "^$module\\s+" || [[ -d "/sys/module/$module" ]]; then
    log "kernel module $module is loaded"
    return 0
  fi

  log "kernel module $module is missing"
  return 1
}

has_linux_capability() {

  if capsh --print | grep -Eq "^Current: = .*,?${1}(,|$)"; then
    return 0
  fi

  return 1
}

is_debug_requested() {

  if echo "${!ENV_VAR_NFS_LOG_LEVEL}" | grep -Eqi '^DEBUG$'; then
    return 0
  fi

  return 1
}

get_requested_count_nfsd_threads() {

  if [[ -n "${!ENV_VAR_NFS_SERVER_THREAD_COUNT}" ]]; then
    echo "${!ENV_VAR_NFS_SERVER_THREAD_COUNT}"
  else
    local -r cpu_count="$(grep -Ec ^processor /proc/cpuinfo)"
    on_failure bail 'unable to detect CPU count. set NFS_SERVER_THREAD_COUNT environment variable'
    echo "$cpu_count";
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

  local -r module=$1

  if is_kernel_module_loaded "$module"; then
    return
  fi

  if [[ ! -d /lib/modules ]] || ! has_linux_capability 'sys_module'; then
    bail "$module module is not loaded in the Docker host's kernel (try: modprobe $module)"
  fi

  log "attempting to load kernel module $module"
  modprobe -v "$module"
  on_failure bail "unable to dynamically load kernel module $module. try modproble $module on the Docker host"

  if ! is_kernel_module_loaded "$module"; then
    bail "modprobe claims that it loaded kernel module $module, but it still appears to be missing"
  fi
}

assert_port() {

  local -r variable_name=$1
  local -r value=${!variable_name}

  if [[ -n "$value" && ( "$value" -lt 1 || "$value" -gt 65535 ) ]]; then
    bail "please set $variable_name to an integer between 1 and 65535 inclusive"
  fi
}

assert_nfs_version() {

  local -r requested_version="$(get_requested_nfs_version)"

  echo "$requested_version" | grep -Eq '^3$|^4(\.[1-2])?$'
  on_failure bail "please set $ENV_VAR_NFS_VERSION to one of: 4.2, 4.1, 4, 3"

  if ! is_nfs3_enabled && [[ "$requested_version" = '3' ]]; then
    bail 'you cannot simultaneously enable and disable NFS version 3'
  fi
}

assert_nfsd_threads() {

  if [[ "$(get_requested_count_nfsd_threads)" -lt 1 ]]; then
    bail "please set $ENV_VAR_NFS_SERVER_THREAD_COUNT to a positive integer"
  fi
}

assert_at_least_one_export() {

  # ensure /etc/exports has at least one line
  grep -Evq "$REGEX_EXPORTS_LINES_TO_SKIP" $PATH_FILE_ETC_EXPORTS
  on_failure bail "$PATH_FILE_ETC_EXPORTS has no exports"
}

assert_cap_sysadmin() {

  if ! has_linux_capability 'cap_sys_admin'; then
    bail 'missing CAP_SYS_ADMIN. be sure to run this image with --cap-add SYS_ADMIN or --privileged'
  fi
}

assert_log_level() {

  if ! echo "${!ENV_VAR_NFS_LOG_LEVEL}" | grep -Eqi "^$|^DEBUG$"; then
    bail "the only acceptable value for $ENV_VAR_NFS_LOG_LEVEL is DEBUG"
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

  local count_valid_exports=0
  local exports=''
  local candidate_export_vars
  local candidate_export_var

  # collect all candidate environment variable names
  candidate_export_vars=$(compgen -A variable | grep -E 'NFS_EXPORT_[0-9]+' | sort)
  on_failure bail 'failed to detect NFS_EXPORT_* variables'

  if [[ -z "$candidate_export_vars" ]]; then
    bail "please provide $PATH_FILE_ETC_EXPORTS to the container or set at least one NFS_EXPORT_* environment variable"
  fi

  log "building $PATH_FILE_ETC_EXPORTS from environment variables"

  for candidate_export_var in $candidate_export_vars; do

    local line="${!candidate_export_var}"

    # skip comments and empty lines
    if [[ "$line" =~ $REGEX_EXPORTS_LINES_TO_SKIP ]]; then
      log_warning "skipping $candidate_export_var environment variable since it contains only whitespace or a comment"
      continue;
    fi

    local line_as_array
    read -r -a line_as_array <<< "$line"
    local dir="${line_as_array[0]}"

    if [[ ! -d "$dir" ]]; then
      log_warning "skipping $candidate_export_var environment variable since $dir is not a container directory"
      continue
    fi

    if [[ $count_valid_exports -gt 0 ]]; then
      exports=$exports$'\n'
    fi

    exports=$exports$line

    (( count_valid_exports++ ))

  done

  log "collected $count_valid_exports valid export(s) from NFS_EXPORT_* environment variables"

  if [[ $count_valid_exports -eq 0 ]]; then
    bail 'no valid exports'
  fi

  echo "$exports" > $PATH_FILE_ETC_EXPORTS
  on_failure bail "unable to write to $PATH_FILE_ETC_EXPORTS"
}

init_assertions() {

  # validate any user-supplied environment variables
  assert_port "$ENV_VAR_NFS_PORT"
  assert_port "$ENV_VAR_NFS_PORT_MOUNTD"
  assert_port "$ENV_VAR_NFS_PORT_STATD_IN"
  assert_port "$ENV_VAR_NFS_PORT_STATD_OUT"
  assert_nfs_version
  assert_nfsd_threads
  assert_log_level

  # check kernel modules
  assert_kernel_mod nfs
  assert_kernel_mod nfsd

  # make sure we have at least one export
  assert_at_least_one_export

  # ensure we have CAP_SYS_ADMIN
  assert_cap_sysadmin

  # perform Kerberos assertions
  if is_kerberos_requested; then

    assert_file_provided "$PATH_FILE_ETC_KRB5_KEYTAB"
    assert_file_provided "$PATH_FILE_ETC_KRB5_CONF"

    assert_kernel_mod rpcsec_gss_krb5
  fi
}


######################################################################################
### boot helpers
######################################################################################

boot_helper_mount() {

  local -r path=$1
  local -r type=$(basename "$path")
  local args=('-t' "$type" "$path")

  if is_debug_requested; then
    args+=('-vvv')
  fi

  log "mounting $type filesystem onto $path"
  mount "${args[@]}"
  on_failure stop "unable to mount $type filesystem onto $path"
}

boot_helper_get_version_flags() {

  local -r requested_version="$(get_requested_nfs_version)"
  local flags=('--nfs-version' "$requested_version" '--no-nfs-version' 2)

  if ! is_nfs3_enabled; then
    flags+=('--no-nfs-version' 3)
  fi

  if [[ "$requested_version" = '3' ]]; then
    flags+=('--no-nfs-version' 4)
  fi

  echo "${flags[@]}"
}

boot_helper_start_daemon() {

  local -r msg="$1"
  local -r daemon="$2"
  shift 2
  local -r daemon_args=("$@")

  log "$msg"
  "$daemon" "${daemon_args[@]}"
  on_failure stop "$daemon failed"
}

boot_helper_start_non_daemon() {

  local -r msg="$1"
  local -r process="$2"
  shift 2
  local -r process_args=("$@")

  log "$msg"
  "$process" "${process_args[@]}" &

  local -r bg_pid=$!

  # somewhat arbitrary assumption that if the process isn't dead already, it will die within 1/20 of a second. for our
  # purposes this works just fine, but if someone has a better solution please open a PR.
  sleep .05
  kill -0 $bg_pid 2> /dev/null
  on_failure stop "$process failed"
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

  local args=('-ar')
  if is_debug_requested; then
    args+=('-v')
  fi

  boot_helper_start_daemon 'exporting filesystem(s)' $PATH_BIN_EXPORTFS "${args[@]}"
}

boot_main_mountd() {

  local version_flags
  read -r -a version_flags <<< "$(boot_helper_get_version_flags)"
  local -r port=$(get_requested_port_mountd)
  local args=('--port' "$port" "${version_flags[@]}")
  if is_debug_requested; then
    args+=('--debug' 'all')
  fi

  # yes, rpc.mountd is required even for NFS v4: https://forums.gentoo.org/viewtopic-p-7724856.html#7724856
  boot_helper_start_daemon "starting rpc.mountd on port $port" $PATH_BIN_MOUNTD "${args[@]}"
}

boot_main_rpcbind() {

  # rpcbind isn't required for NFSv4, but if it's not running then nfsd takes over 5 minutes to start up.
  # it's a bug in either nfs-utils or the kernel, and the code of both is over my head.
  # so as a workaround we start rpcbind now and (in v4-only scenarios) kill it after nfsd starts up
  local -r args=('-ds')
  boot_helper_start_daemon 'starting rpcbind' $PATH_BIN_RPCBIND "${args[@]}"
}

boot_main_idmapd() {

  if ! is_idmapd_requested; then
    return
  fi

  local args=('-S')
  local func=boot_helper_start_daemon
  if is_debug_requested; then
    args+=('-vvv' '-f')
    func=boot_helper_start_non_daemon
  fi

  $func 'starting idmapd' $PATH_BIN_IDMAPD "${args[@]}"
}

boot_main_statd() {

  if ! is_nfs3_enabled; then
    return
  fi

  local -r port_in=$(get_requested_port_statd_in)
  local -r port_out=$(get_requested_port_statd_out)
  local -r args=('--no-notify' '--port' "$port_in" '--outgoing-port' "$port_out")

  boot_helper_start_daemon "starting statd on port $port_in (outgoing from port $port_out)" $PATH_BIN_STATD "${args[@]}"
}

boot_main_nfsd() {

  local version_flags
  read -r -a version_flags <<< "$(boot_helper_get_version_flags)"
  local -r threads=$(get_requested_count_nfsd_threads)
  local -r port=$(get_requested_port_nfsd)
  local args=('--tcp' '--udp' '--port' "$port" "${version_flags[@]}" "$threads")

  if is_debug_requested; then
    args+=('--debug')
  fi

  boot_helper_start_daemon "starting rpc.nfsd on port $port with $threads server thread(s)" $PATH_BIN_NFSD "${args[@]}"

  if ! is_nfs3_enabled; then
    kill_process_if_running "$PATH_BIN_RPCBIND"
  fi
}

boot_main_svcgssd() {

  if ! is_kerberos_requested; then
    return
  fi

  local args=('-f')
  if is_debug_requested; then
    args+=('-vvv')
  fi

  boot_helper_start_non_daemon 'starting rpc.svcgssd' $PATH_BIN_RPC_SVCGSSD "${args[@]}"
}


######################################################################################
### boot summary
######################################################################################

summarize_nfs_versions() {

  local -r reqd_version="$(get_requested_nfs_version)"
  local versions=''

  case "$reqd_version" in
    4\.2)
      versions='4.2, 4.1, 4'
      ;;
    4\.1)
      versions='4.1, 4'
      ;;
    4)
      versions='4'
      ;;
    *)
      versions='3'
      ;;
  esac

  if is_nfs3_enabled && [[ "$reqd_version" =~ ^4 ]]; then
    versions="$versions, 3"
  fi

  log "list of enabled NFS protocol versions: $versions"
}

summarize_exports() {

  log 'list of container exports:'

  # if debug is enabled, read /var/lib/nfs/etab as it contains the "real" export data. but it also contains more
  # information that most people will usually need to see
  local file_to_read="$PATH_FILE_ETC_EXPORTS"
  if is_debug_requested; then
    file_to_read='/var/lib/nfs/etab'
  fi

  while read -r export; do

    # skip comments and empty lines
    if [[ "$export" =~ $REGEX_EXPORTS_LINES_TO_SKIP ]]; then
      continue;
    fi

    # log it w/out leading and trailing whitespace
    log "  $(echo -e "$export" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  done < "$file_to_read"
}

summarize_ports() {

  local -r port_nfsd="$(get_requested_port_nfsd)"
  local -r port_mountd="$(get_requested_port_mountd)"
  local -r port_statd_in="$(get_requested_port_statd_in)"

  if ! is_nfs3_enabled; then
    log "list of container ports that should be exposed: $port_nfsd (TCP)"
  else
    log 'list of container ports that should be exposed:'
    log '  111 (TCP and UDP)'
    log "  $port_nfsd (TCP and UDP)"
    log "  $port_statd_in (TCP and UDP)"
    log "  $port_mountd (TCP and UDP)"
  fi
}


######################################################################################
### main routines
######################################################################################

init() {

  log_header 'setting up ...'

  init_exports
  init_assertions
  init_trap

  log 'setup complete'
}

boot() {

  log_header 'starting services ...'

  boot_main_mounts
  boot_main_rpcbind
  boot_main_exportfs
  boot_main_mountd
  boot_main_statd
  boot_main_idmapd
  boot_main_nfsd
  boot_main_svcgssd

  log 'all services started normally'
}

summarize() {

  log_header 'server startup complete'

  summarize_nfs_versions
  summarize_exports
  summarize_ports
}

hangout() {

  log_header 'ready and waiting for NFS client connections'

  # wait forever or until we get SIGTERM or SIGINT
  # https://stackoverflow.com/a/41655546/229920
  # https://stackoverflow.com/a/27694965/229920
  while :; do sleep 2073600 & wait; done
}

main() {

  init
  boot
  summarize
  hangout
}

main
