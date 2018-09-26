# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2018-09-26

### Added
* upon successful server startup, log:
  * list of enabled NFS versions
  * list of exports
  * list of ports that should be exposed
* improved error detection and logging

## [1.1.1] - 2018-08-21

### Fixed

* baked-in `/etc/exports` is not properly recognized ([#9](https://github.com/ehough/docker-nfs-server/issues/9))

## [1.1.0] - 2018-06-06

### Added

* Base image is now configurable via `BUILD_FROM` build argument. e.g. `docker build --build-arg BUILD_FROM=ubuntu erichough/nfs-server` ([#3](https://github.com/ehough/docker-nfs-server/pull/3))

### Changed

* Base image is now `debian:stretch-slim` (was `debian:stable`)

### Fixed

* `rpc.idmapd` was started even when NFS version 4 was not in use
* removed default `/etc/idmapd.conf` from the image to prevent unintended start of `rpc.idmapd`
* `NFS_VERSION=3` resulted in `rpc.nfsd` still offering version 4
* Fixed detection of built-in kernel modules ([#4](https://github.com/ehough/docker-nfs-server/pull/4))

## [1.0.0] - 2018-02-05
Initial release.