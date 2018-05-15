# erichough/nfs-server

A lightweight, robust, flexible, and containerized NFS server.

## Why?

This is the only containerized NFS server that offers **all** of the following features:

- NFS versions 3, 4, or both simultaneously
- optional Kerberos security
- optional name/ID mapping via [`idmapd`](http://man7.org/linux/man-pages/man8/idmapd.8.html)
- clean teardown of services upon `SIGTERM` or `SIGKILL` (no lingering `nfsd` processes on Docker host)
- flexible construction of `/etc/exports` via a Docker bind mount *or* environment variables
- extensive server configuration via environment variables

## Requirements

1. The Docker **host** kernel will need the following kernel modules
   - `nfs`
   - `nfsd`
   - `rpcsec_gss_krb5` (*only if Kerberos is used*)
 
   Usually you can enable these modules with: `modprobe {nfs,nfsd,rpcsec_gss_krb5}`
1. The container will need to run with `CAP_SYS_ADMIN` (or `--privileged`). This is necessary as the server needs to mount several filesystems inside the container to support its operation, and performing mounts from inside a container is impossible without these capabilities.
1. The container will need local access to the files you'd like to serve via NFS. You can use Docker volumes, bind mounts, or files baked into a custom image. e.g.

   - `-v some_volume:/some/container/path` (Docker volume)
   - `-v /some/path/on/host:/some/container/path` (bind mount)
   - `ADD /some/path/on/host /some/container/path` (Dockerfile)

## Usage

### Hello, World!

You will need to provide your desired [NFS exports](https://linux.die.net/man/5/exports) (`/etc/exports`) upon container startup. You have **three choices** for doing this:

1. **Bind mount `/etc/exports` into the container**

       docker run                                      \
         -v /host/path/to/exports.txt:/etc/exports:ro  \
         -v /host/files:/nfs                           \
         --cap-add SYS_ADMIN                           \
         -p 2049:2049                                  \
         erichough/nfs-server:latest
         
1. **Provide each line of `/etc/exports` as an environment variable**.

    The container will look for environment variables that start with `NFS_EXPORT_` and end with an integer. e.g. `NFS_EXPORT_0`, `NFS_EXPORT_1`, etc.

       docker run                                                            \
         -e NFS_EXPORT_0='/nfs/foo 192.168.1.0/24(ro,no_subtree_check)'      \
         -e NFS_EXPORT_1='/nfs/bar 123.123.123.123/32(rw,no_subtree_check)'  \
         -v /host/path/foo:/nfs/foo                                          \
         -v /host/path/bar:/nfs/bar                                          \
         --cap-add SYS_ADMIN                                                 \
         -p 2049:2049                                                        \
         erichough/nfs-server:latest

1. **Bake `/etc/exports` into a custom image**

    e.g. in a `Dockerfile`:

       FROM ehough/nfs-server:latest
       ADD /host/path/to/exports.txt /etc/exports

### (Optional) User ID Mapping

If you'd like to run [`idmapd`](http://man7.org/linux/man-pages/man8/idmapd.8.html) to map between NFSv4 IDs (e.g. `foo@bar.com`) and local users, simply provide [`idmapd.conf`](https://linux.die.net/man/5/idmapd.conf) and `/etc/passwd` to the container. This step is required for Kerberos.

       docker run                                          \
         -v /host/path/to/exports.txt:/etc/exports:ro      \
         -v /host/files:/nfs                               \
         -v /host/path/to/idmapd.conf:/etc/idmapd.conf:ro  \
         -v /etc/passwd:/etc/passwd:ro                     \
         --cap-add SYS_ADMIN                               \
         -p 2049:2049                                      \
         erichough/nfs-server:latest
         
### (Optional) Kerberos

You can enable Kerberos security by performing the following additional actions:

1. set the environment variable `NFS_ENABLE_KERBEROS` to a non-empty value (e.g. `NFS_ENABLE_KERBEROS=1`)
1. set the server's hostname via the `--hostname` flag
1. provide `/etc/krb5.keytab` which contains a principal of the form `nfs/<hostname>`, where `<hostname>` is the hostname you supplied in the previous step.
1. provide [`/etc/krb5.conf`](https://web.mit.edu/kerberos/krb5-1.12/doc/admin/conf_files/krb5_conf.html)
1. provide [`/etc/idmapd.conf`](https://linux.die.net/man/5/idmapd.conf)
1. provide `/etc/passwd` that contains your NFS client users

Here's an example:

       docker run                                            \
         -v /host/path/to/exports.txt:/etc/exports:ro        \
         -v /host/files:/nfs                                 \
         -e NFS_ENABLE_KERBEROS=1                            \
         --hostname my-nfs-server.com                        \
         -v /host/path/to/server.keytab:/etc/krb5.keytab:ro  \
         -v /host/path/to/server.krb5conf:/etc/krb5.conf:ro  \
         -v /host/path/to/idmapd.conf:/etc/idmapd.conf:ro    \
         -v /etc/passwd:/etc/passwd:ro                       \
         --cap-add SYS_ADMIN                                 \
         -p 2049:2049                                        \
         erichough/nfs-server:latest

### Environment Variables

The following optional environment variables allow you to adjust the server settings to your needs.

- **`NFS_VERSION`** (default is `4.2`)

  Set to `3`, `4`, `4.1`, or `4.2` to fine tune the NFS protocol version. Enabling any version will also enable any lesser versions. e.g. `4.2` will enable versions 4.2, 4.1, 4, **and** 3.

- **`NFS_DISABLE_VERSION_3`** (*not set by default*)

  Set to a non-empty value (e.g. `NFS_DISABLE_VERSION_3=1`) to disable NFS version 3 and run a version-4-only server. This setting is not compatible with `NFS_VERSION=3`.

- **`NFS_PORT`** (default is `2049`)

  Set this to any valid port number (`1` - `65535` inclusive) to change `rpc.nfsd`'s listening port.

- **`NFS_SERVER_THREAD_COUNT`** (default is *CPU core count*)

  Set this to a positive integer to control how many server threads `rpc.nfsd` will use. A good minimum is one thread per CPU core, but 4 or 8 threads per core is probably better.

- **`NFS_PORT_MOUNTD`** (default is `32767`)

  *Only needed for NFS 3*. Set this to any valid port number (`1` - `65535` inclusive) to change `rpc.mountd`'s listening port.

- **`NFS_PORT_STATD_IN`** (default is `32765`)

  *Only needed for NFS 3*. Set this to any valid port number (`1` - `65535` inclusive) to change `rpc.statd`'s listening port.

- **`NFS_PORT_STATD_OUT`** (default is `32766`)

  *Only needed for NFS 3*. Set this to any valid port number (`1` - `65535` inclusive) to change `rpc.statd`'s outgoing connection port.
  
- **`NFS_ENABLE_KERBEROS`** (*not set by default*)

  Set to a non-empty value (e.g. `NFS_ENABLE_KERBEROS=1`) to enable Kerberos on this server. See "Kerberos" section above for further details.

### Mounting filesystems from a client

    # mount -o nfsvers=4 <container-IP>:/some/export /some/local/path
    
### Connecting to the running container

    # docker exec -it <container-id> bash

## Performance considerations

- Running the container with `--network host` *might* improve network performance by 10% - 20% [[1](https://jtway.co/docker-network-performance-b95bce32b4b9),[2](https://www.percona.com/blog/2016/08/03/testing-docker-multi-host-network-performance/)], though this hasn't been tested.

## Remaining tasks

- switch back to Alpine Linux once [this bug](https://bugs.alpinelinux.org/issues/8470) in `nfs-utils` is fixed
- figure out why `rpc.nfsd` takes 5 minutes to startup/timeout unless `rpcbind` is running

## Acknowledgements

This work was based heavily on prior projects:

- [f-u-z-z-l-e/docker-nfs-server](https://github.com/f-u-z-z-l-e/docker-nfs-server)
- [sjiveson/nfs-server-alpine](https://github.com/sjiveson/nfs-server-alpine)