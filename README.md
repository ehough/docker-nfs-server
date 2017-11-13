# ehough/docker-nfs-server

A lightweight, robust, flexible, and containerized NFS server.

## Why?

This is the only containerized NFS server that offers **all** of the following features:

- NFS versions 3, 4, or both simultaneously
- clean teardown of services upon `SIGTERM` or `SIGKILL` (no lingering `nfsd` processes on Docker host)
- flexible construction of `/etc/exports` via a Docker bind mount *or* environment variables
- lightweight image based on [Alpine Linux](https://alpinelinux.org/)
- ability to control server parameters via environment variables

## Requirements

1. The Docker **host** kernel will need both the `nfs` and `nfsd` kernel modules. Usually you can enable them both with `modprobe nfs nfsd`.
1. The container will need to run with `CAP_SYS_ADMIN` (or `--privileged`). This is necessary as the server needs to mount several filesystems inside the container to support its operation.
1. You will need to bind mount your exported filesystems into this container. e.g. `-v /some/path/on/host:/some/container/path`

## Usage

### Starting the container

The container requires you to supply it with your desired [NFS exports](https://linux.die.net/man/5/exports) upon startup. You have **two choices** for doing this:

1. **Bind mount a full exports file into the container at `/etc/exports`**.

       docker run \
         -v /host/path/to/exports.txt:/etc/exports:ro \
         -v /host/files:/nfs \
         --cap-add SYS_ADMIN \
         -p 2049:2049 \
         erichough/nfs-server:latest
         
1. **Supply each line of `/etc/exports` as an environment variable**.

    The container will look for environment variables that start with `NFS_EXPORT_` and end with an integer. e.g. `NFS_EXPORT_0`, `NFS_EXPORT_1`, etc.

       docker run \
         -e NFS_EXPORT_0='/nfs/foo 192.168.1.0/24(ro,no_subtree_check)' \
         -e NFS_EXPORT_1='/nfs/bar 123.123.123.123/32(rw,no_subtree_check)' \
         -v /host/path/foo:/nfs/foo \
         -v /host/path/bar:/nfs/bar \
         --cap-add SYS_ADMIN \
         -p 2049:2049 \
         erichough/nfs-server:latest

### Configuration

Via optional environment variables, you can adjust the server settings to your needs.

- **`NFS_VERSION`** (default is `4.2`)

  Set to `3`, `4`, `4.1`, or `4.2` to fine tune the NFS protocol version. Enabling any version will also enable any lesser versions. e.g. `4.2` will enable versions 4.2, 4.1, 4, **and** 3.

- **`NFS_VERSION_DISABLE_V3`** (*not set by default*)

  Set to a non-empty value (e.g. `NFS_VERSION_DISABLE_V3=1`) to disable NFS version 3 and run a version-4-only server. This setting is not compatible with `NFS_VERSION=3`.

- **`NFSD_PORT`** (default is `2049`)

  Set this to any valid port number (`1` - `65535` inclusive) to change `rpc.nfsd`'s listening port.

- **`NFSD_SERVER_THREADS`** (default is *CPU core count*)

  Set this to a positive integer to control how many server threads `rpc.nfsd` will use. A good minimum is one thread per CPU core, but 4 or 8 threads per core is probably better.

- **`NFS_MOUNTD_PORT`** (default is `32767`)

  *Only needed for NFS 3*. Set this to any valid port number (`1` - `65535` inclusive) to change `rpc.mountd`'s listening port.

- **`NFS_STATD_IN_PORT`** (default is `32765`)

  *Only needed for NFS 3*. Set this to any valid port number (`1` - `65535` inclusive) to change `rpc.statd`'s listening port.

- **`NFS_STATD_OUT_PORT`** (default is `32766`)

  *Only needed for NFS 3*. Set this to any valid port number (`1` - `65535` inclusive) to change `rpc.statd`'s outgoing connection port.

### Mounting filesystems from a client

    # mount -o nfsvers=4 <container-IP>:/some/export /some/local/path
    
### Connecting to the running container

    # docker exec -it <container-id> bash

## Performance considerations

- Running the container with `--network host` *might* improve network performance by 10% - 20% [[1](https://jtway.co/docker-network-performance-b95bce32b4b9),[2](https://www.percona.com/blog/2016/08/03/testing-docker-multi-host-network-performance/)], though this hasn't been tested.

## Remaining tasks

- figure out why `rpc.nfsd` takes 5 minutes to startup/timeout unless `rpcbind` is running
- add `rpc.idmapd`
- add NFS v4 security (`rpc.svcgssd`, `rpc.gssd`, etc.)

## Acknowledgements

This work was based heavily on prior projects:

- [f-u-z-z-l-e/docker-nfs-server](https://github.com/f-u-z-z-l-e/docker-nfs-server)
- [sjiveson/nfs-server-alpine](https://github.com/sjiveson/nfs-server-alpine)
