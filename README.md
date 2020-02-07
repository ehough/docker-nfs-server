# erichough/nfs-server

A lightweight, robust, flexible, and containerized NFS server.

## Why?

This is the only containerized NFS server that offers **all** of the following features:

- small (~15MB) Alpine Linux image
- NFS versions 3, 4, or both simultaneously
- clean teardown of services upon termination (no lingering `nfsd` processes on Docker host)
- flexible construction of `/etc/exports`
- extensive server configuration via environment variables
- human-readable logging (with a helpful [debug mode](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/logging.md))
- *optional* bonus features
  - [Kerberos security](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/kerberos.md)
  - [NFSv4 user ID mapping](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/nfs4-user-id-mapping.md) via [`idmapd`](http://man7.org/linux/man-pages/man8/idmapd.8.html)
  - [AppArmor](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/apparmor.md) compatibility

## Table of Contents

* [Requirements](#requirements)
* Usage
  * [Starting the server](#starting-the-server)
  * [Mounting filesystems from a client](#mounting-filesystems-from-a-client)
* Optional features
  * [Debug logging](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/logging.md)
  * [Kerberos security](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/kerberos.md)
  * [NFSv4 user ID mapping](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/nfs4-user-id-mapping.md)
  * [AppArmor integration](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/apparmor.md)
* Advanced
  * [automatically load required kernel modules](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/auto-load-kernel-modules.md)
  * [custom server ports](https://github.com/ehough/docker-nfs-server/blob/develop/doc/advanced/ports.md)
  * [custom NFS versions offered](https://github.com/ehough/docker-nfs-server/blob/develop/doc/advanced/nfs-versions.md)
  * [performance tuning](https://github.com/ehough/docker-nfs-server/blob/develop/doc/advanced/performance-tuning.md)
* [Help!](#help)
* [Remaining tasks](#remaining-tasks)
* [Acknowledgements](#acknowledgements)

## Requirements

1. The Docker **host** kernel will need the following kernel modules
   - `nfs`
   - `nfsd`
   - `rpcsec_gss_krb5` (*only if Kerberos is used*)

   You can manually enable these modules on the Docker host with:
   
   `modprobe {nfs,nfsd,rpcsec_gss_krb5}`
   
   or you can just allow the container to [load them automatically](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/auto-load-kernel-modules.md).
1. The container will need to run with `CAP_SYS_ADMIN` (or `--privileged`). This is necessary as the server needs to mount several filesystems *inside* the container to support its operation, and performing mounts from inside a container is impossible without these capabilities.
1. The container will need local access to the files you'd like to serve via NFS. You can use Docker volumes, bind mounts, files baked into a custom image, or virtually any other means of supplying files to a Docker container.

## Usage

### Starting the server

Starting the `erichough/nfs-server` image will launch an NFS server. You'll need to supply some information upon container startup, which we'll cover below, but briefly speaking your `docker run` command might look something like this:

    docker run                                            \
      -v /host/path/to/shared/files:/some/container/path  \
      -v /host/path/to/exports.txt:/etc/exports:ro        \
      --cap-add SYS_ADMIN                                 \
      -p 2049:2049                                        \
      erichough/nfs-server

Let's break that command down into its individual pieces to see what's required for a successful server startup.

1. **Provide the files to be shared over NFS**

   As noted in the [requirements](#requirements), the container will need local access to the files you'd like to share over NFS. Some ideas for supplying these files:

      * [bind mounts](https://docs.docker.com/storage/bind-mounts/) (`-v /host/path/to/shared/files:/some/container/path`)
      * [volumes](https://docs.docker.com/storage/volumes/) (`-v some_volume:/some/container/path`)
      * files [baked into](https://docs.docker.com/engine/reference/builder/#copy) custom image (e.g. in a `Dockerfile`: `COPY /host/files /some/container/path`)

   You may use any combination of the above, or any other means to supply files to the container.

1. **Provide your desired [NFS exports](https://linux.die.net/man/5/exports) (`/etc/exports`)**

   You'll need to tell the server which **container directories** to share. You have *three options* for this; choose whichever one you prefer:

   1. bind mount `/etc/exports` into the container

          docker run                                      \
            -v /host/path/to/exports.txt:/etc/exports:ro  \
            ...                                           \
            erichough/nfs-server

   1. provide each line of `/etc/exports` as an environment variable

       The container will look for environment variables that start with `NFS_EXPORT_` and end with an integer. e.g. `NFS_EXPORT_0`, `NFS_EXPORT_1`, etc.

          docker run                                                                       \
            -e NFS_EXPORT_0='/container/path/foo                  *(ro,no_subtree_check)'  \
            -e NFS_EXPORT_1='/container/path/bar 123.123.123.123/32(rw,no_subtree_check)'  \
            ...                                                                            \
            erichough/nfs-server

   1. bake `/etc/exports` into a custom image

       e.g. in a `Dockerfile`:

       ```Dockerfile
       FROM erichough/nfs-server
       ADD /host/path/to/exports.txt /etc/exports
       ```

1. **Use `--cap-add SYS_ADMIN` or `--privileged`**

   As noted in the [requirements](#requirements), the container will need additional privileges. So your `run` command will need *either*:

       docker run --cap-add SYS_ADMIN ... erichough/nfs-server
       
    or

       docker run --privileged ... erichough/nfs-server

    Not sure which to use? Go for `--cap-add SYS_ADMIN` as it's the lesser of two evils.

1. **Expose the server ports**

   You'll need to open up at least one server port for your client connections. The ports listed in the examples below are the defaults used by this image and most can be [customized](https://github.com/ehough/docker-nfs-server/blob/develop/doc/advanced/ports.md).

   * If your clients connect via **NFSv4 only**, you can get by with just TCP port `2049`:

         docker run -p 2049:2049 ... erichough/nfs-server

   * If you'd like to support **NFSv3**, you'll need to expose a lot more ports:

         docker run                          \
           -p 2049:2049   -p 2049:2049/udp   \
           -p 111:111     -p 111:111/udp     \
           -p 32765:32765 -p 32765:32765/udp \
           -p 32767:32767 -p 32767:32767/udp \
           ...                               \
           erichough/nfs-server

If you pay close attention to each of the items in this section, the server should start quickly and be ready to accept your NFS clients.

### Mounting filesystems from a client

    # mount <container-IP>:/some/export /some/local/path

## Optional Features

  * [Debug logging](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/logging.md)
  * [Kerberos security](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/kerberos.md)
  * [NFSv4 user ID mapping](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/nfs4-user-id-mapping.md)
  * [AppArmor integration](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/apparmor.md)

## Advanced

  * [automatically load required kernel modules](https://github.com/ehough/docker-nfs-server/blob/develop/doc/feature/auto-load-kernel-modules.md)
  * [customizing which ports are used](https://github.com/ehough/docker-nfs-server/blob/develop/doc/advanced/ports.md)
  * [customizing NFS versions offered](https://github.com/ehough/docker-nfs-server/blob/develop/doc/advanced/nfs-versions.md)
  * [performance tuning](https://github.com/ehough/docker-nfs-server/blob/develop/doc/advanced/performance-tuning.md)

## Help!

Please [open an issue](https://github.com/ehough/docker-nfs-server/issues) if you have any questions, constructive criticism, or can't get something to work.

## Remaining tasks

- figure out why `rpc.nfsd` [takes 5 minutes to startup/timeout](https://www.spinics.net/lists/linux-nfs/msg59728.html) unless `rpcbind` is running
- add more examples

## Acknowledgements

This work was based on prior projects:

- [f-u-z-z-l-e/docker-nfs-server](https://github.com/f-u-z-z-l-e/docker-nfs-server)
- [sjiveson/nfs-server-alpine](https://github.com/sjiveson/nfs-server-alpine)
