# Customize NFS versions offered

By default, this image provides NFS versions 3 and 4 simultaneously. Using the following environment variables, you can fine-tune which versions are offered.

| Environment variable    | Description                                                                                                                                                                                | Default   |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|
| `NFS_VERSION`           | Set to `3`, `4`, `4.1`, or `4.2` to fine tune the NFS protocol version. Enabling any version will also enable any lesser versions. e.g. `4.1` will enable versions 4.1, 4, **and** 3. | `4.2`     |
| `NFS_DISABLE_VERSION_3` | Set to a non-empty value (e.g. `NFS_DISABLE_VERSION_3=1`) to disable NFS version 3 and run a version-4-only server. This setting is not compatible with `NFS_VERSION=3`                    | *not set* |