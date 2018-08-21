# NFSv4 User ID Mapping

If you'd like to run [`idmapd`](http://man7.org/linux/man-pages/man8/idmapd.8.html) to map between NFSv4 IDs (e.g. `foo@bar.com`) and local users, simply provide [`idmapd.conf`](https://linux.die.net/man/5/idmapd.conf) and `/etc/passwd` to the container. This step is required for [Kerberos](kerberos.md).

    docker run                                          \
      -v /host/path/to/exports.txt:/etc/exports:ro      \
      -v /host/files:/nfs                               \
      -v /host/path/to/idmapd.conf:/etc/idmapd.conf:ro  \
      -v /etc/passwd:/etc/passwd:ro                     \
      --cap-add SYS_ADMIN                               \
      -p 2049:2049                                      \
      erichough/nfs-server
         