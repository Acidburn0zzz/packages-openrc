#!/bin/bash
## build.sh: all the steps for building openrc and/or eudev packages

git_clean(){
    git clean -dfx  # Remove untracked directories and files
}

get_user(){
    echo $(ls ${WORKDIR} | cut -d' ' -f1 | grep -v root | grep -v lock)
}

rm_bl_pkg(){
    local blacklist=('libsystemd')
    sudo pacman -Rdd ${blacklist[@]} -r ${WORKDIR}/$(get_user) --noconfirm
}

inst_pkg(){
    sudo pacman -U *${ARCH}*pkg*z -r ${WORKDIR}/$(get_user) --noconfirm
}

chroot_init(){
    cd $1 && echo "==> Start building $1"
    sudo ${BRANCH}-${ARCH}-build ${NOCLEAN} -r ${CHROOT} #-- ${NOVERIFY} ${NOCLEAN}
    rm_bl_pkg && inst_pkg
    echo "==> End building $1" && cd ..
}

# $1: name
chroot_pkg(){
    for pkg in $(cat ${PROFDIR}/$1); do
	cd $pkg && echo "==> Start building $pkg"
	#sudo makechrootpkg ${NOVERIFY} -b ${BRANCH} -r ${WORKDIR} -- ${NOCLEAN} || break
	sudo makechrootpkg ${NOVERIFY} -b ${BRANCH} -r ${WORKDIR} || break
	echo "==> End building $pkg" && cd ..
    done
}

cp_pkg(){
    if [[ ! -d "${PKGDIR}" ]]; then
	mkdir -p ${PKGDIR}
    fi

    case $1 in
	all)
	    cd eudev
	    cp *.pkg.tar.xz ${PKGDIR}
	    cd ..
	    for pkg in $(cat ${PROFDIR}/$1); do
	    cd $pkg
		    cp *.pkg.tar.xz ${PKGDIR}
	    cd ..
	    done
	;;
	sysvinit | eudev)
	    cd $1
	    cp *.pkg.tar.xz ${PKGDIR}
	    cd ..
	    for pkg in $(cat ${PROFDIR}/$1); do
	    cd $pkg
		    cp *.pkg.tar.xz ${PKGDIR}
	    cd ..
	    done
	;;
	*) break ;;
    esac
}

sign_pkg(){
	cd ${PKGDIR} &&	signpkgs && cd ..
}

run(){
    git_clean

    case ${PROFILE} in
	sysvinit)
	    echo "==> Start building profile ${PROFILE}"
	    chroot_init "${PROFILE}"
	    chroot_pkg "${PROFILE}"
	    echo "==> Finished building profile ${PROFILE}"
	    cp_pkg "${PROFILE}"
	    if (( ${SIGN} ));then
		    sign_pkg
	    fi
	;;
	eudev)
	    echo "==> Start building profile ${PROFILE}"
	    chroot_init "${PROFILE}"
	    chroot_pkg "${PROFILE}"
	    echo "==> Finished building profile ${PROFILE}"
	    cp_pkg  "${PROFILE}"
	    if (( ${SIGN} ));then
		    sign_pkg
	    fi
	;;
	all)
	    echo "==> Start building profile ${PROFILE}"
	    chroot_init "eudev"
	    chroot_pkg "${PROFILE}"
	    echo "==> Finished building profile ${PROFILE}"
	    cp_pkg  "all"
	    if (( ${SIGN} ));then
		    sign_pkg
	    fi
	;;
	*)
	    echo "==> Start building package ${PROFILE}"
	    chroot_init "${PROFILE}"
	    echo "==> Finished building package ${PROFILE}"
	    cp_pkg  "${PROFILE}"
	    if (( ${SIGN} ));then
		    sign_pkg
	    fi
	;;
    esac
}

########################MAIN################################

export LANG=C
export LC_MESSAGES=C

BRANCH=unstable
ARCH=$(uname -m)
PROFILE=all # all,eudev,sysvinit, or single package
CHROOT=/srv/manjarobuild
SIGN=0
NOCLEAN='-c'
UPDATE=''
NOVERIFY='-n'
RUNDIR=$(pwd)
PKGDIR=${RUNDIR}/packages/
PROFDIR=${RUNDIR}/profiles

usage() {
    echo 'Usage: build.sh [options]'
    echo ' options:'
    echo '    -b <branch>         [default] '"${BRANCH}"
    echo '    -a <arch>           [default] '"${ARCH}"
    echo '    -p <profile>        [default] '"${PROFILE}"
    echo '    -s                  sign packages'
    echo '    -n                  no clean chroot'
    echo '    -x                  no namcap checks'
    echo '    -h                  Help'
    exit 1
}

while getopts 'b:a:p:snxh' arg; do
    case "${arg}" in
	b) BRANCH=$OPTARG ;;
	a) ARCH=$OPTARG ;;
	p) PROFILE=$OPTARG ;;
	s) SIGN=1 ;;
	n) NOCLEAN='' ;;
	x) NOVERIFY='' ;;
	h|*) usage ;;
    esac
done
shift $((OPTIND-1))

WORKDIR=${CHROOT}/${BRANCH}-${ARCH}

run $@
