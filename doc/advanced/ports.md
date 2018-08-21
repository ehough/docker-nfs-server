# Customizing ports

You can customize the ports used by the NFS server via the environment variables listed below. Each environment variable can be set to an integer between `1` and `65535`.

| Environment variable | Description                                 | Default |
|----------------------|---------------------------------------------|---------|
| `NFS_PORT`           | `rpc.nfsd`'s listening port.                | `2049`  |
| `NFS_PORT_MOUNTD`    | *NFSv3 only*. `rpc.mountd'` listening port. | `32767` |
| `NFS_PORT_STATD_IN`  | *NFSv3 only*. `rpc.statd`'s listening port. | `32765` |
| `NFS_PORT_STATD_OUT` | *NFSv3 only*. `rpc.statd`'s outgoing port.  | `32766` |