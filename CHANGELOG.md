# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [unreleased]

### Fixed
* Broken links in README, both on GitHub and Docker Hub ([#29](https://github.com/ehough/docker-nfs-server/issues/29), [#35](https://github.com/ehough/docker-nfs-server/issues/35))

### Changed
* Use pure Bash for uppercasing strings ([#36](https://github.com/ehough/docker-nfs-server/issues/36))

## [2.2.1] - 2019-03-15

### Fixed
* `rpc.statd` debug output was invisible

### Changed
* Further de-cluttered non-debug logging output

## [2.2.0] - 2019-03-08

### Added
* Enhanced debugging via environment variable: `NFS_LOG_LEVEL=DEBUG`. This also produces less cluttered log output
during regular, non-debug operation.

### Fixed
* `idmapd` would not start when `NFS_VERSION=3`
* allow Kerberos without `idmapd`. Most users will probably want to run them together, but 
it isn't required.
* `NFS_VERSION` environment variable sanity check allowed invalid values
* status code of `rpc.svcgssd` was not properly checked
* `idmapd` debug output was invisible

## [2.1.0] - 2019-01-31

### Added
* Ability to automatically load kernel modules. ([#18](https://github.com/ehough/docker-nfs-server/issues/18)). Credit to [@andyneff](https://github.com/andyneff).

### Fixed
* Minor bugs in `entrypoint.sh`

## [2.0.0] - 2019-01-31

### Changed
 * Switch to Alpine Linux

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
