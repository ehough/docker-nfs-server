# Kerberos

You can enable Kerberos security for your NFS server with the following steps.

1. set the environment variable `NFS_ENABLE_KERBEROS` to a non-empty value (e.g. `NFS_ENABLE_KERBEROS=1`)
1. set the server's hostname via the `--hostname` flag
1. provide `/etc/krb5.keytab` which contains a principal of the form `nfs/<hostname>`, where `<hostname>` is the hostname you supplied in the previous step.
1. provide [`/etc/krb5.conf`](https://web.mit.edu/kerberos/krb5-1.12/doc/admin/conf_files/krb5_conf.html)

Here's an example:

    docker run                                            \
      -v /host/path/to/exports.txt:/etc/exports:ro        \
      -v /host/files:/nfs                                 \
      -e NFS_ENABLE_KERBEROS=1                            \
      --hostname my-nfs-server.com                        \
      -v /host/path/to/server.keytab:/etc/krb5.keytab:ro  \
      -v /host/path/to/server.krb5conf:/etc/krb5.conf:ro  \
      --cap-add SYS_ADMIN                                 \
      -p 2049:2049                                        \
      erichough/nfs-server
