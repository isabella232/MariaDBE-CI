#!/usr/bin/env bash
#
set -xe
#
cd $(dirname ${0})
#
CMAKE_DEFAULT_ARGS="-DBUILD_CONFIG=enterprise -DMYSQL_MAINTAINER_MODE=OFF"
CMAKE_ARGS=${CMAKE_DEFAULT_ARGS}
ASAN_ARGS="-DWITH_ASAN=ON"
BUILD_TYPE=${BUILD_TYPE:-RelWithDebInfo}
OS=$(uname -s)
NCPU=
PKGARG=package
PLATFORM=${IMAGE:-ubuntu-2004}
GIT_BRANCH=
GIT_CLEAN=no
TOPDIR="${PWD}/.."
BUILDDIR=${TOPDIR}/build
TARGET=${TOPDIR}/target
CMAKE_RUNDIR=..
FETCH_COMPAT=no
EXT=tar.gz
#
function show_help {
cat <<-EOF
  Parameters are:"
    --debug-build     - to compile in debug mode
    --with-asan       - to compile with ASAN
EOF
}

while [[ ${#} -gt 0 ]]; do
  case ${1} in
    --make-sourcetar)
      PKGARG=dist
      shift
      ;;
    --make-rpm)
      FETCH_COMPAT=yes
      EXT=rpm
      CMAKE_ARGS+=" -DRPM=${PLATFORM/-/}"
      shift
      ;;
    --make-deb)
      EXT=deb
      shift
      ;;
    --with-asan)
      CMAKE_ARGS+=" ${ASAN_ARGS}"
      shift
      ;;
    --build-type)
      BUILD_TYPE=${2}
      shift 2
      ;;
    --source-tarball)
      SOURCETAR=${2}
      shift 2
      ;;
    *)
      echo "Unknown parameter ${1}!"
      show_help
      exit 1
      ;;
  esac
done
#
CMAKE_ARGS+=" -DCMAKE_BUILD_TYPE=${BUILD_TYPE}"
# TODO
# remove after Werror fixes in debug mode
# [[ ${BUILD_TYPE} = Debug ]] && CMAKE_ARGS+=" -DMYSQL_MAINTAINER_MODE=OFF"
#
if [[ ${OS} = Darwin ]]; then
  CMAKE_ARGS+=" -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl@1.1/"
  CMAKE_ARGS+=" -DOPENSSL_INCLUDE_DIR=/usr/local/opt/openssl@1.1/include/"
  CMAKE_ARGS+=" -DOPENSSL_LIBRARIES=/usr/local/opt/openssl@1.1/lib/"
  NCPU=$(system_profiler SPHardwareDataType | grep -i 'Number of Cores' | awk '{print $NF}')
  PLATFORM=MacOS
fi
#
if [[ ${OS} = Linux ]]; then
  NCPU=$(grep -c processor /proc/cpuinfo)
fi
#
case ${PLATFORM} in
  centos-6|rhel-6)
    CMAKE_ARGS+=" -DCMAKE_C_COMPILER=/opt/rh/devtoolset-3/root/usr/bin/gcc"
    CMAKE_ARGS+=" -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-3/root/usr/bin/g++"
    ;;
  *)
    echo "No need to set specific settings for ${PLATFORM}"
    ;;
esac
#
rm -fr ${BUILDDIR}
mkdir -p ${BUILDDIR} ${TARGET}
#
cd ${BUILDDIR}
#
if [[ ${EXT} = deb ]]; then
  cd ${TOPDIR}
  [[ ${PLATFORM} = "debian-8" ]] && sed s/"dch -b"/"dch -b --force-distribution"/g -i debian/autobake-deb.sh
  debian/autobake-deb.sh
  mv -vf ${TOPDIR}/../*.${EXT} ${TARGET}/
else
  if [[ ${FETCH_COMPAT} = yes ]]; then
    case ${PLATFORM} in
      centos-6|rhel-6)
        curl -o ${TOPDIR}/MariaDB-shared-5.3.x.rpm  \
        http://yum.mariadb.org/5.3/centos5-amd64/rpms/MariaDB-shared-5.3.12-122.el5.x86_64.rpm
        curl -o ${TOPDIR}/../MariaDB-shared-10.1.x.rpm \
        http://yum.mariadb.org/10.1/centos6-amd64/rpms/MariaDB-10.1.41-centos6-x86_64-shared.rpm
        ;;
      centos-7|rhel-7)
        curl -o ${TOPDIR}/../MariaDB-shared-5.3.x.rpm  \
        http://yum.mariadb.org/5.3/centos5-amd64/rpms/MariaDB-shared-5.3.12-122.el5.x86_64.rpm
        curl -o ${TOPDIR}/../MariaDB-shared-10.1.x.rpm \
        http://yum.mariadb.org/10.1/centos7-amd64/rpms/MariaDB-shared-10.1.41-1.el7.centos.x86_64.rpm
        ;;
      sles-12|sles-15)
        curl -o ${TOPDIR}/../MariaDB-shared-5.3.x.rpm  \
        http://yum.mariadb.org/5.3/centos5-amd64/rpms/MariaDB-shared-5.3.12-122.el5.x86_64.rpm
        curl -o ${TOPDIR}/../MariaDB-shared-10.1.x.rpm \
        http://yum.mariadb.org/10.1/sles12-amd64/rpms/MariaDB-shared-10.1.41-1.x86_64.rpm
        ;;
    esac
  fi
#
  cmake ${CMAKE_RUNDIR} ${CMAKE_ARGS}
  make -j${NCPU} ${PKGARG} VERBOSE=1
  mv -vf ${BUILDDIR}/*.${EXT} ${TARGET}/
fi
