# AppArmor

If your Docker host has [AppArmor](https://wiki.ubuntu.com/AppArmor) activated, you'll need to perform additional steps to allow the container to start an NFS server.

1. Ensure you have the `apparmor-utils` installed package installed on the Docker host. e.g. for Debian or Ubuntu:

       $ sudo apt-get install apparmor-utils

1. Create a file on the Docker host with the following contents:

       #include <tunables/global>
       profile erichough-nfs flags=(attach_disconnected,mediate_deleted) {
         #include <abstractions/lxc/container-base>
         mount fstype=nfs*,
         mount fstype=rpc_pipefs,
       }
       
1. Load this profile into the kernel with [`apparmor_parser`](http://manpages.ubuntu.com/manpages/xenial/man8/apparmor_parser.8.html):

       $ sudo apparmor_parser -r -W /path/to/file/from/previous/step

1. Add `--security-opt apparmor=erichough-nfs` to your `docker run` command. e.g.

       docker run                                \
         -v /path/to/share:/nfs                  \
         -v /path/to/exports.txt:/etc/exports:ro \
         --cap-add SYS_ADMIN                     \
         -p 2049:2049                            \
         --security-opt apparmor=erichough-nfs   \
         erichough/nfs-server
         
   or in `docker-compose.yml`:
   
   ```YAML
   version: 3
   services:
     nfs:
       image: erichough/nfs-server
       volumes:
         - /path/to/share:/nfs
         - /path/to/exports.txt:/etc/exports:ro
       cap_add:
         - SYS_ADMIN
       ports:
         - 2049:2049
       security_opt:
         - apparmor=erichough-nfs
   ```