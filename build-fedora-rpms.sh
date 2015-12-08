#!/bin/bash

set -e
set -x

# make a current upstream snapshot tar.gz

BUILDDIR=`pwd`
EDSCRIPT=`realpath $SCRIPTDIR/`/patch-selinux-policy.spec.ed
FEDORASRPMSTORE=copr/selinux
MOCKROOT=fedora-rawhide-x86_64
SCRIPTDIR=$(realpath `dirname $0`)

mkdir -p $BUILDDIR/build-fedora-rpms/{packages,RPMS,SRPMS,BUILD}

cd $BUILDDIR/build-fedora-rpms

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

if [[ ! -d selinux.merged.git ]]; then
        git clone https://github.com/bachradsusi/selinux.git selinux.merged.git
	cd selinux.merged.git
	git checkout master-with-upstream-master
	git remote add SELinuxProject $BUILDDIR/selinux.git
	git fetch SELinuxProject
	cd -
else
        cd selinux.merged.git
	git checkout master-with-upstream-master
        git pull

	git fetch SELinuxProject
        cd -
fi

if [[ ! -d build-selinuxproject-rpms.git ]]; then
	git clone https://github.com/bachradsusi/build-selinuxproject-rpms.git build-selinuxproject-rpms.git
else
	cd build-selinuxproject-rpms.git
	git pull
	cd -
fi

for package in libsepol libselinux setools libsemanage policycoreutils checkpolicy selinux-policy; do
	# checkout or pull a package
	pushd $BUILDDIR/packages/
	if [[ ! -d $package ]]; then
		if [[ $package = "setools" ]]; then
			git clone https://pagure.io/setools3.git setools
		else
			fedpkg clone -a $package
			cd $package
			if [[ $package != "selinux-policy" ]]; then
				cp $BUILDDIR/build-selinuxproject-rpms.git/packages/$package/$package.spec .
			else
				ed selinux-policy.spec < $EDSCRIPT
			fi
			fedpkg sources
			cd -
		fi
	else
		cd $package
		if [[ $package != "selinux-policy" ]]; then
			git pull --rebase
		else
			git fetch
			git reset --hard origin/master
			ed selinux-policy.spec < $EDSCRIPT
		fi
		cd -
	fi

	# make a -rhat.patch
	pushd $package
	if [[ -f $package-rhat.patch ]]; then
		cd $BUILDDIR/selinux.merged.git
		git diff SELinuxProject/master $package/  > $BUILDDIR/packages/$package/$package-rhat.patch
		if [[ $package = "policycoreutils" ]]; then
			git diff SELinuxProject/master sepolgen/ > $BUILDDIR/packages/$package/sepolgen-rhat.patch
		fi
		
	fi
	popd
	popd
	if [[ $package != "setools" ]]; then
		gitrev_s=$selinux_gitrev_s
		gitrev=$selinux_gitrev
		git_dir=$selinux_dir
		git archive --format=tar HEAD $package | gzip > $BUILDDIR/packages/$package/$package-$gitrev_s.tar.gz
	else
		gitrev_s=$setools3_gitrev_s
		gitrev=$setools3_gitrev
		git_dir=$setools3_dir
	fi

	# bump the package relase
	pushd $BUILDDIR/packages/$package
	if grep -q "gitrev $gitrev_s" $package.spec; then
		popd
		continue
		# git reset --hard HEAD~
	fi
	rpmdev-bumpspec -c "build from $gitrev" $package.spec
	sed -i "s/^\%global gitrev .*/\%global gitrev $gitrev_s/" $package.spec
	popd

	# update source tarballs
	if [[ $package != "setools" && $package != "selinux-policy" ]]; then
		pushd $BUILDDIR/selinux.git
		git archive --format=tar HEAD $package/ | gzip > $BUILDDIR/packages/$package/$package-$gitrev_s.tar.gz
		if [[ $package = "policycoreutils" ]]; then
			git archive --format=tar HEAD sepolgen | gzip > $BUILDDIR/packages/$package/sepolgen-$gitrev_s.tar.gz
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
		scp $BUILDDIR/SRPMS/$package-$package_verrel.src.rpm fedora:public_html/$FEDORASRPMSTORE
		copr-cli build  plautrba/selinux http://plautrba.fedorapeople.org/$FEDORASRPMSTORE/$package-$package_verrel.src.rpm
	else
		mock -r $MOCKROOT --resultdir=$BUILDDIR/RPMS/$package --rebuild $BUILDDIR/SRPMS/$package-$package_verrel.src.rpm
		rm $BUILDDIR/RPMS/$package/$package*$package_verrel.src.rpm
		mock -r $MOCKROOT --update $BUILDDIR/RPMS/$package/$package*$package_verrel.*.rpm || :
		mock -r $MOCKROOT --install $BUILDDIR/RPMS/$package/$package*$package_verrel*.rpm || :
	fi

	# update package's spec.file
	#### pushd $BUILDDIR/packages/$package/
	#### git add $package.spec
	#### git commit -m "$package-$package_verrel - rebuild from $gitrev_s"
	#### popd
	cp $BUILDDIR/packages/$package/$package.spec $SCRIPTDIR/packages/$package/
	cd $SCRIPTDIR/
	git add packages/$package
	cd -

	if [[ -n $INTERACTIVE ]]; then
	  	read -i "continue?" y
	  	if [[ $y != "y" ]]; then
	  		exit
	  	fi
	fi

done



