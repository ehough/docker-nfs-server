# Automatically load required kernel modules

*Credit to Andy Neff [@andyneff](https://github.com/andyneff) for this idea.*

As noted in the `README`, the Docker host kernel needs a few modules for proper operation of an NFS server. You can manually enable these on the host - i.e. with `modprobe` - or you can allow the container to do this on your behalf. Here's how:

1. Add `--cap-add SYS_MODULE` to your Docker run command to allow the container to load/unload kernel modules.
1. Bind-mount the Docker host's `/lib/modules` directory into the container. e.g. `-v /lib/modules:/lib/modules:ro`

Here's an example `docker-compose.yml`:

   ```YAML
   version: 3
   services:
     nfs:
       image: erichough/nfs-server
       volumes:
         - /path/to/share:/nfs
         - /path/to/exports.txt:/etc/exports:ro
         - /lib/modules:/lib/modules:ro
       cap_add:
         - SYS_ADMIN
         - SYS_MODULE
       ports:
         - 2049:2049
   ```