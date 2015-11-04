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

## Usage

### Build dependencies

Install dependencies:

    $ dnf install audit-libs-devel bison bzip2-devel dbus-devel dbus-glib-devel flex flex-devel flex-static glib2-devel libcap-devel libcap-ng-devel pam-devel pcre-devel python-devel setools-devel swig ustr-devel rpm-build fedpkg

For local mock builds you need to prepare `selinux-86_64` build repository:

    # sudo -i
    # cp /etc/mock/fedora-rawhide-x86_64.cfg /etc/mock/selinux-x86_64.cfg
    # sed -i "s/config_opts['root'] = 'fedora-23-x86_64'/config_opts['root'] = 'selinux-x86_64'/" /etc/mock/selinux-x86_64.cfg
    # echo -e "config_opts['cleanup_on_success'] = 0\nconfig_opts['cleanup_on_failure'] = 0\nconfig_opts['clean'] = False" >> /etc/mock/selinux-x86_64.cfg

    $ mock -r selinux-x86_64 --init
    $ mock -r selinux-x86_64 --install libsemanage-devel libsemanage-static libsepol-static libsepol-devel
    
### Execution

    $ ./build-selinuxproject-rpms.sh

The scripts creates its directory structure in a current directory:

    build-selinuxproject-rpms/SRPMS
    build-selinuxproject-rpms/BUILD
    build-selinuxproject-rpms/packages
    build-selinuxproject-rpms/setools3.git
    build-selinuxproject-rpms/selinux.git
    build-selinuxproject-rpms/RPMS

rpms are build in *BUILD* directory from src.rpm in *SRPMS* with results stored in *RPMS*.



