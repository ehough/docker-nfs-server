# AppArmor

If your Docker host has [AppArmor](https://wiki.ubuntu.com/AppArmor) activated, you'll need to perform additional steps to allow the container to start an NFS server.

1. Ensure you have the `apparmor-utils` installed package installed on the Docker host. e.g. for Debian:

       $ sudo apt-get install apparmor-utils

1. Create a file on the Docker host with the following contents:

       #include <tunables/global>
       profile erichough-nfs flags=(attach_disconnected,mediate_deleted) {
         #include <abstractions/lxc/container-base>
         mount fstype=nfs*,
         mount fstype=rpc_pipefs,
       }
       
1. Load this profile into AppArmor:

       $ sudo apparmor_parser -r -W /path/to/file/from/previous/step

1. Add `--security-opt apparmor=erichough-nfs` to your `docker run` command. e.g.

       docker run                                \
         -v /path/to/exports.txt:/etc/exports:ro \
         -v /path/to/share:/nfs                  \
         --cap-add SYS_ADMIN                     \
         -p 2049:2049                            \
         --security-opt apparmor=erichough-nfs   \
         erichough/nfs-server
