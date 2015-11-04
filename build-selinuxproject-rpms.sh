#!/bin/bash

set -e

BUILDDIR=`pwd`

mkdir -p $BUILDDIR/build-selinuxproject-rpms/{packages,RPMS,SRPMS,BUILD}

cd $BUILDDIR/build-selinuxproject-rpms

BUILDDIR=`pwd`

if [[ ! -d selinux.git ]]; then
	git clone https://github.com/SELinuxProject/selinux.git selinux.git
else
	cd selinux.git
	git pull
	cd -
fi

pushd selinux.git

selinux_gitrev_s=`git rev-parse --verify --short HEAD`
selinux_gitrev=`git rev-parse --verify HEAD`
selinux_dir=selinux.git

popd

if [[ ! -d setools3.git ]]; then
	git clone https://github.com/TresysTechnology/setools3.git setools3.git
else
	cd setools3.git
	git pull
	cd -
fi

pushd setools3.git

setools3_gitrev_s=`git rev-parse --verify --short HEAD`
setools3_gitrev=`git rev-parse --verify HEAD`
setools3_dir=setools3.git

popd

for package in libsepol libselinux setools libsemanage policycoreutils checkpolicy; do
	if [[ $package != "setools" ]]; then
		gitrev_s=$selinux_gitrev_s
		gitrev=$selinux_gitrev
		git_dir=$selinux_dir
	else
		gitrev_s=$setools3_gitrev_s
		gitrev=$setools3_gitrev
		git_dir=$setools3_dir
	fi

	# checkout or pull a package
	pushd $BUILDDIR/packages/
	if [[ ! -d $package ]]; then
		if [[ $package = "setools" ]]; then
			git clone https://pagure.io/setools3.git setools
		else
			fedpkg clone -a $package
			cd $package
			git checkout private-upstream-master
			fedpkg sources
			cd -
		fi
	else
		cd $package
		git pull
		cd -
	fi
	popd

	# bump the package relase
	pushd $BUILDDIR/packages/$package
	if grep -q "gitrev $gitrev_s" $package.spec; then
		popd
		continue
	fi
	rpmdev-bumpspec -c "build from $gitrev" $package.spec
	sed -i "s/^\%global gitrev .*/\%global gitrev $gitrev_s/" $package.spec
	popd

	# update source tarballs
	if [[ $package != "setools" ]]; then
		pushd $BUILDDIR/selinux.git
		git archive --format=tar HEAD $package/ | gzip > $BUILDDIR/packages/$package/$package-2.5-$gitrev_s.tar.gz
		if [[ $package = "policycoreutils" ]]; then
			git archive --format=tar HEAD sepolgen | gzip > $BUILDDIR/packages/$package/sepolgen-1.2.3-$gitrev_s.tar.gz
		fi
		popd
	fi
	if [[ $package = "setools" ]]; then
		pushd $BUILDDIR/setools3.git
		git archive --format=tar --prefix=setools-3.3.8/ HEAD | bzip2 > $BUILDDIR/packages/$package/$package-3.3.8-$setools3_gitrev_s.tar.bz2
		popd
	fi

	# build src.rpm
	rpmbuild --define "_sourcedir $BUILDDIR/packages/$package/" --define "_srcrpmdir $BUILDDIR/SRPMS" --define "_rpmdir $BUILDDIR/RPMS" --define "_builddir $BUILDDIR/BUILD" -bs $BUILDDIR/packages/$package/$package.spec
	package_verrel=`rpm -q --qf "%{VERSION}-%{RELEASE}  " --specfile packages/$package/$package.spec | cut -f 1 -d " "`

	# build packages
	if [[ -n $COPRBUILD ]]; then
		scp $BUILDDIR/SRPMS/$package-$package_verrel.src.rpm fedora:public_html/selinux-master
		copr-cli build  plautrba/selinux-master http://plautrba.fedorapeople.org/selinux-master/$package-$package_verrel.src.rpm
	else
		mock -r selinux-x86_64 --resultdir=$BUILDDIR/RPMS/$package --rebuild $BUILDDIR/SRPMS/$package-$package_verrel.src.rpm
		mock -r selinux-x86_64 --update $BUILDDIR/RPMS/$package/$package*$package_verrel.*.rpm | :
		mock -r selinux-x86_64 --install $BUILDDIR/RPMS/$package/$package*$package_verrel*.rpm | :
	fi

	# update package's spec.file
	pushd $BUILDDIR/packages/$package/
	git add $package.spec
	git commit -m "$package-$package_verrel - rebuild from $gitrev_s"
	popd

	if [[ -n $INTERACTIVE ]]; then
	  	read -i "continue?" y
	  	if [[ $y != "y" ]]; then
	  		exit
	  	fi
	fi

done

