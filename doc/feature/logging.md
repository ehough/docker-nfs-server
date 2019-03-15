# Logging

By default, the image will output a reasonable level of logging information so you can verify that the server is operating as expected.

You can adjust the logging level via the `NFS_LOG_LEVEL` environment variable. Currently, the only acceptable values are `INFO` (default) and `DEBUG`.

In your `docker-run` command:
```
docker run -e NFS_LOG_LEVEL=DEBUG ... erichough/nfs-server
```
or in `docker-compose.yml`:
```YAML
version: 3
services:
  nfs:
    image: erichough/nfs-server
    ...
    environment:
      - NFS_LOG_LEVEL: DEBUG
```
   
### Normal log output

Normal, non-debug logging will look something like this:

```
==================================================================
      SETTING UP ...
==================================================================
----> building /etc/exports from environment variables
----> collected 3 valid export(s) from NFS_EXPORT_* environment variables
----> setup complete

==================================================================
      STARTING SERVICES ...
==================================================================
----> starting rpcbind
----> starting exportfs
----> starting rpc.mountd on port 32767
----> starting rpc.statd on port 32765 (outgoing from port 32766)
----> starting rpc.idmapd
----> starting rpc.nfsd on port 2049 with 16 server thread(s)
----> starting rpc.svcgssd
----> all services started normally

==================================================================
      SERVER STARTUP COMPLETE
==================================================================
----> list of enabled NFS protocol versions: 3
----> list of container exports:
---->   /nfs/htpc-media *(ro,no_subtree_check,insecure,async)
---->   /nfs/homes/staff *(rw,no_subtree_check,insecure,no_root_squash,sec=krb5p)
---->   /nfs/homes/ehough *(rw,no_subtree_check,insecure,no_root_squash,sec=krb5p)
----> list of container ports that should be exposed:
---->   111 (TCP and UDP)
---->   2049 (TCP and UDP)
---->   32765 (TCP and UDP)
---->   32767 (TCP and UDP)

==================================================================
      READY AND WAITING FOR NFS CLIENT CONNECTIONS
==================================================================

```

### Debug output

Debug output will be much more detailed, and it may be very helpful when diagnosing NFS problems.

```
==================================================================
      SETTING UP ...
==================================================================
----> log level set to DEBUG
----> will use requested rpc.nfsd thread count of 16
----> building /etc/exports from environment variables
----> collected 3 valid export(s) from NFS_EXPORT_* environment variables
----> kernel module nfs is loaded
----> kernel module nfsd is loaded
----> kernel module rpcsec_gss_krb5 is loaded
----> setup complete

==================================================================
      STARTING SERVICES ...
==================================================================
----> mounting rpc_pipefs filesystem onto /var/lib/nfs/rpc_pipefs
mount: mount('rpc_pipefs','/var/lib/nfs/rpc_pipefs','rpc_pipefs',0x00008000,'(null)'):0
----> mounting nfsd filesystem onto /proc/fs/nfsd
mount: mount('nfsd','/proc/fs/nfsd','nfsd',0x00008000,'(null)'):0
----> starting rpcbind
----> starting exportfs
exporting *:/nfs/homes/ehough
exporting *:/nfs/homes/staff
exporting *:/nfs/htpc-media
----> starting rpc.mountd on port 32767
----> starting rpc.statd on port 32765 (outgoing from port 32766)
----> starting rpc.idmapd
----> starting rpc.nfsd on port 2049 with 16 server thread(s)
rpc.nfsd: knfsd is currently down
rpc.nfsd: Writing version string to kernel: -2 +3 +4 +4.1 +4.2
rpc.nfsd: Created AF_INET TCP socket.
rpc.nfsd: Created AF_INET UDP socket.
rpc.nfsd: Created AF_INET6 TCP socket.
rpc.nfsd: Created AF_INET6 UDP socket.
rpc.idmapd: Setting log level to 11

----> starting rpc.svcgssd
rpc.idmapd: libnfsidmap: using domain: hough.matis
rpc.idmapd: libnfsidmap: Realms list: 'HOUGH.MATIS' 
rpc.idmapd: libnfsidmap: processing 'Method' list
rpc.idmapd: static_getpwnam: name 'nfs/blue@HOUGH.MATIS' mapped to 'root'
rpc.idmapd: static_getpwnam: localname 'melissa' for 'melissa@HOUGH.MATIS' not found
rpc.idmapd: static_getpwnam: name 'ehough@HOUGH.MATIS' mapped to 'ehough'
libtirpc: debug level 3
rpc.idmapd: static_getgrnam: group 'nfs/blue@HOUGH.MATIS' mapped to 'root'
rpc.idmapd: static_getgrnam: local group 'melissa' for 'melissa@HOUGH.MATIS' not found
rpc.idmapd: static_getgrnam: group 'ehough@HOUGH.MATIS' mapped to 'ehough'
rpc.idmapd: libnfsidmap: loaded plugin /usr/lib/libnfsidmap/static.so for method static
rpc.idmapd: Expiration time is 600 seconds.
rpc.idmapd: Opened /proc/net/rpc/nfs4.nametoid/channel
rpc.idmapd: Opened /proc/net/rpc/nfs4.idtoname/channel
entering poll
----> all services started normally

==================================================================
      SERVER STARTUP COMPLETE
==================================================================
----> list of enabled NFS protocol versions: 4.2, 4.1, 4, 3
----> list of container exports:
---->   /nfs/homes/ehough       *(rw,sync,wdelay,hide,nocrossmnt,insecure,no_root_squash,no_all_squash,no_subtree_check,secure_locks,acl,no_pnfs,anonuid=65534,anongid=65534,sec=krb5p,rw,insecure,no_root_squash,no_all_squash)
---->   /nfs/homes/staff        *(rw,sync,wdelay,hide,nocrossmnt,insecure,no_root_squash,no_all_squash,no_subtree_check,secure_locks,acl,no_pnfs,anonuid=65534,anongid=65534,sec=krb5p,rw,insecure,no_root_squash,no_all_squash)
---->   /nfs/htpc-media *(ro,async,wdelay,hide,nocrossmnt,insecure,root_squash,no_all_squash,no_subtree_check,secure_locks,acl,no_pnfs,anonuid=65534,anongid=65534,sec=sys,ro,insecure,root_squash,no_all_squash)
----> list of container ports that should be exposed:
---->   111 (TCP and UDP)
---->   2049 (TCP and UDP)
---->   32765 (TCP and UDP)
---->   32767 (TCP and UDP)

==================================================================
      READY AND WAITING FOR NFS CLIENT CONNECTIONS
==================================================================
rpc.statd: Version 2.3.2 starting
rpc.statd: Flags: No-Daemon Log-STDERR TI-RPC 
rpc.statd: Failed to read /var/lib/nfs/state: Address in use
rpc.statd: Initializing NSM state
rpc.statd: Local NSM state number: 3
rpc.statd: Failed to open /proc/sys/fs/nfs/nsm_local_state: Read-only file system
rpc.statd: Running as root.  chown /var/lib/nfs to choose different user
rpc.statd: Waiting for client connections
leaving poll
handling null request
svcgssd_limit_krb5_enctypes: Calling gss_set_allowable_enctypes with 7 enctypes from the kernel
sname = nfs/blue@HOUGH.MATIS
doing downcall
mech: krb5, hndl len: 4, ctx len 52, timeout: 1552111964 (31564 from now), clnt: nfs@blue, uid: 0, gid: 0, num aux grps: 1:
  (   1) 0
sending null reply
writing message: \x \x6082024606092a864886f71201020201006e82023530820231a003020105a10302010ea20703050020000000a38201306182012c30820128a003020105a10d1b0b484f5547482e4d41544953a2153013a003020103a10c300a1b036e66731b036e6173a381fa3081f7a003020113a103020106a281ea0481e79cf640041a02f97332a25760a707a3f039f61301d07b2dfbb8bf9448cbfd168d0958c7717b535f7799c87390469c94045a6cd3f54c91ddeda9274b1ea492a43e6b17dec3ad17aaa94b9e61cdd4f4c8e7a35d8e84d56c7657e63536358e1316e2e8362922b47b465dd57aa29cb743128432decee09c3a06e6b4d5f6cebcd0978ee37bf0155a01a6ed623dc7b3068163fedaadec1e1509788db701c5308c703aa0e3196188e40c22afc361d2d9762750627c091516f05059a1f965df187dc981f4ac59bf3f424f23e676109a8c93af93b66f704f78703e1ef642fddf5b01d7deb40db26642e9f4f0a481e73081e4a003020111a281dc0481d9299c7ea474abf5d08a5f4f977254552e712f783f89bf40eb2cbd0082614593e377ec8cfe1c1ffb1bc0fad366382258f63857928240933914478fbceadc3b3bfe2e1f9a477c601d6b20c19898813878f45cea78ae601a342f000faf89c2e0e4c37fdb5db7937ac327ac0470c1f97dd421a112a6739467132d598db38ff99f9a88a8ac44e72f5cd088bd4d6159e15be75a7447d556134bda4fa0a96e64e3350d3a198e0635e4e7fb4900962aed3912fe0f316a1fa27121133232816b1177c707c0c37b396add3b347be38db756f05815ca3de5b3874782d80bf9 1552080460 0 0 \x01000000 \x60819906092a864886f71201020202006f8189308186a003020105a10302010fa27a3078a003020111a271046fdfb95cbe1237d785691a0ca14b4f7443142dda2b2a1b2845499bdb69b538719fbfc99b71d72ae61d7bd9966c106b2381fd08690082de26da5b8f521081035b5d7b8bf6c6eda85fd73c1c76ff03bec7693695e0b3d9e72069ec3772f93c4dbc5e8ce698a0854b494714bd5801204af3 
finished handling null request
entering poll
...
```