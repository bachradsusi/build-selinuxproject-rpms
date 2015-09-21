#!/bin/bash

mkdir build-selinuxproject-rpms

cd build-selinuxproject-rpms
BUILDDIR=`pwd`

# if [[ -z $1 ]]; then
# 	git clone https://github.com/SELinuxProject/selinux.git selinux.git
# 	pushd selinux.git
# else
# 	pushd $1
# 	git pull
# fi

pushd ~/devel/github/SELinuxProject/selinux.git

git pull
gitrev_s=`git rev-parse --verify --short HEAD`
gitrev=`git rev-parse --verify HEAD`

popd

for package in libsepol libselinux libsemanage policycoreutils checkpolicy secilc; do
	pushd ~/devel/github/SELinuxProject/selinux.git
	git archive --format=tar HEAD $package/ | gzip > ~/devel/fedora/$package/master/$package-2.5-$gitrev_s.tar.gz
	if [[ $package = "policycoreutils" ]]; then
		git archive --format=tar HEAD sepolgen | gzip > ~/devel/fedora/policycoreutils/master/sepolgen-1.2.3-$gitrev_s.tar.gz
	fi
	popd
	pushd ~/devel/fedora/$package/master
	git checkout private-upstream
	if grep -q "gitrev $gitrev_s" $package.spec; then
		continue
	fi
	rpmdev-bumpspec -c "build from $gitrev" -r $package.spec
	sed -i "s/^\%global gitrev .*/\%global gitrev $gitrev_s/" $package.spec
	rpmbuild --define "_sourcedir `pwd`" --define "_srcrpmdir $BUILDDIR" --define "_rpmdir `pwd`" --define "_builddir `pwd`" -bs $package.spec
	popd
	mock -r selinux-x86_64 --resultdir=$BUILDDIR/$package --rebuild $BUILDDIR/$package-*.src.rpm
	mock -r selinux-x86_64 --update $BUILDDIR/$package/$package*.x86_64.rpm
	mock -r selinux-x86_64 --install $BUILDDIR/$package/$package*.x86_64.rpm
done

