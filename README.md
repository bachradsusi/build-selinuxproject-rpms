# Latest SELinux Userspace builds for Fedora

`build-selinuxproject-rpms.sh` script builds packages for Fedora from
SELinux userspace tools and libraries from the latest git tree on github -
https://github.com/SELinuxProject/selinux.

## Packages

* libsepol
* libselinux
* setools
* libsemanage
* policycoreutils
* checkpolicy

Package sources are tracked in *private-upstream-master* branches in
[Fedora dist git repository](http://pkgs.fedoraproject.org/cgit) with an exception for *setools* which is storedn in [pagure.io/setools3](https://pagure.io/setools3).

## Builds

Source tar balls are created from snapshots of [SELinuxProject/selinux](https://github.com/SELinuxProject/selinux) and 
[TresysTechnology/setools3.git](https://github.com/TresysTechnology/setools3.git).

Builds are stored in [plautrba/selinux-master](https://copr.fedoraproject.org/coprs/plautrba/selinux-master/) repository.

