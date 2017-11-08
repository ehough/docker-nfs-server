# ehough/docker-nfs4-server

A lightweight, robust, flexible, and containerized NFS v4 server.

## Why?

This is the only containerized NFS server that offers **all** of the following features:

- a version-4-only NFS server (no `rpcbind`, no port mapping, etc)
- flexible construction of `/etc/exports` via a Docker bind mount *or* environment variables
- clean teardown of services upon `SIGTERM` or `SIGKILL`
- lightweight image based on Alpine Linux
- ability to control server parameters via environment variables

## Requirements

1. The Docker **host** kernel will need both the `nfs` and `nfsd` kernel modules. Usually you can enable them both with `modprobe nfs nfsd`.
1. The container will need to run with `CAP_SYS_ADMIN` (or `--privilged`). This is necessary as the NFS server will need to perform internal filesystem mounts.
1. You will need to bind mount your exported filesystems into this container. e.g. `-v /some/path/on/host:/some/container/path`

## Usage

### Starting the container

The container requires you to supply it with your desired [NFS exports](https://linux.die.net/man/5/exports) upon startup. You have **two choices** for doing this:

1. **Bind mount an exports file into the container at `/etc/exports`**.

       docker run \
         -v /host/path/to/exports.txt:/etc/exports:ro \
         -v /host/files:/nfs \
         --cap-add SYS_ADMIN \
         -p 2049:2049 \
         erichough/nfs4-server:latest`
         
   A successful start of this form will look like this:
   
       ----> /etc/exports appears to be mounted via Docker
       ----> checking for presence of kernel module: nfs
       ----> checking for presence of kernel module: nfsd
       ----> requirements look good; we should be able to run continue without issues.
       ----> starting rpcbind temporarily to allow rpc.nfsd to start quickly
       ----> starting rpc.nfsd on port 2049 with version 4.2 and 8 server thread(s)
       rpc.nfsd: knfsd is currently down
       rpc.nfsd: Writing version string to kernel: +4.2 -2 -3 +4
       rpc.nfsd: Created AF_INET TCP socket.
       rpc.nfsd: Created AF_INET UDP socket.
       rpc.nfsd: Created AF_INET6 TCP socket.
       rpc.nfsd: Created AF_INET6 UDP socket.
       ----> killing rpcbind now that rpc.nfsd is up
       ----> exporting filesystems
       exporting *:/nfs
       ----> starting rpc.mountd with version 4.2
       ----> nfsd ready and waiting for client connections on port 2049.
         
1. **Supply environment variable triplets to the container to allow it to construct `/etc/exports`**.

    Each triplet should consist of `NFS_EXPORT_DIR_*`, `NFS_EXPORT_CLIENT_*`, and `NFS_EXPORT_OPTIONS_*`. You can add as many triplets as you'd like.

       docker run \
         -e NFS_EXPORT_DIR_0=/nfs \
         -e NFS_EXPORT_CLIENT_0=192.168.1.0/24 \
         -e NFS_EXPORT_OPTIONS_0=rw,no_subtree_check,fsid=0 \
         -v /host/files:/nfs \
         --cap-add SYS_ADMIN \
         -p 2049:2049 \
         erichough/nfs4-server:latest`
         
   A successful start of this form will look like this:

       ----> building /etc/exports
       ----> will export /nfs to * with options ro,no_subtree_check
       ----> will export 1 filesystem(s)
       ----> /etc/exports now contains the following contents:
       /nfs *(ro,no_subtree_check,fsid=0)
       ----> checking for presence of kernel module: nfs
       ----> checking for presence of kernel module: nfsd
       ----> requirements look good; we should be able to run continue without issues.
       ----> starting rpcbind temporarily to allow rpc.nfsd to start quickly
       ----> starting rpc.nfsd on port 2049 with version 4.2 and 8 server thread(s)
       rpc.nfsd: knfsd is currently down
       rpc.nfsd: Writing version string to kernel: +4.2 -2 -3 +4
       rpc.nfsd: Created AF_INET TCP socket.
       rpc.nfsd: Created AF_INET UDP socket.
       rpc.nfsd: Created AF_INET6 TCP socket.
       rpc.nfsd: Created AF_INET6 UDP socket.
       ----> killing rpcbind now that rpc.nfsd is up
       ----> exporting filesystems
       exporting *:/nfs
       ----> starting rpc.mountd with version 4.2
       ----> nfsd ready and waiting for client connections on port 2049.

### Additional tweaks

Via optional environment variables, you can further adjust the server settings.

- **`NFSD_PORT`** (default is `2049`)

  Set this to any valid port number (`1` - `65535` inclusive) to change server's listening port.

- **`NFSD_SERVER_THREADS`** (default is *CPU core count*)

  Set this to a positive integer to control how many server threads rpc.nfsd will use. A good minimum is one thread per CPU core, but 4 or 8 threads per core is recommended.
  
- **`NFS_VERSION`** (default is `4.2`)

  Set to `4`, `4.1`, or `4.2` to fine tune the NFS protocol version. Note that any minor version will also enable any lesser minor versions. e.g. `4.2` will enable `4.2`, `4.1`, *and* `4`.

### Mounting filesystems from a client

    # mount -o nfsvers=4 <container-IP>:/some/export /some/local/path
    
### Connecting to the running container

    # docker exec -it <container-id> bash

## Performance considerations

- Running the container with `--network=host` *might* improve network performance by 10% - 20% [[1](https://jtway.co/docker-network-performance-b95bce32b4b9),[2](https://www.percona.com/blog/2016/08/03/testing-docker-multi-host-network-performance/)], though this hasn't been tested.

## Remaining tasks

- figure out why `rpcbind` is *temporarily* required to start `rpc.nfsd` without a 5 minute delay
- add `rpc.idmapd`
- add NFS v4 security (`rpc.svcgssd`, `rpc.gssd`, etc.)

## Acknowledgements

This work was based heavily on prior projects:

- [f-u-z-z-l-e/docker-nfs-server](https://github.com/f-u-z-z-l-e/docker-nfs-server)
- [sjiveson/nfs-server-alpine](https://github.com/sjiveson/nfs-server-alpine)