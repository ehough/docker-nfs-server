# docker-compose example

## Introduction

The example provided [docker-compose file](docker-compose.yml) allows for:
* building the container,
* running the container in `NFS v4` mode only (`NFS v3` is disabled) - see more
  in the
  [customize NFS versions](../advanced/nfs-versions.md#customize-nfs-versions-offered)

Following stuff gets mounted into the contianer:

* `nfs-export` directory:

```
nfs-export
└── debian
    ├── a
    ├── b
    ├── c
    └── d
```

* `exports.txt` file:

```
/export         *(rw,fsid=0,no_subtree_check,sync)
/export/debian  *(rw,nohide,insecure,no_subtree_check,sync)
```

## Build

In order to build the container:

```
docker-compose build
```

## Run

In order to run the container:

```
docker-compose up
```

## Test

Check if we can mount the directory:

```
sudo mount LOCAL_IP:/ /mnt -v
```

In the command output we can inspect which `NFS` version was used:

```
mount.nfs: timeout set for Thu Jan 31 16:16:20 2019
mount.nfs: trying text-based options 'vers=4.2,addr=LOCAL_IP,clientaddr=LOCAL_IP'
```

Inspect mounted directory content:

```
/mnt
└── debian
    ├── a
    ├── b
    ├── c
    └── d
```
