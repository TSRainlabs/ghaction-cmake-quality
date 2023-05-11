FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN set -x -e; \
    apt-get -y update; \
    apt-get -y install --no-install-recommends apt-transport-https ca-certificates gnupg software-properties-common wget; \
    rm -rf /var/lib/apt/lists/*

RUN set -x -e; \
    wget https://apt.llvm.org/llvm.sh; \
    chmod +x llvm.sh; \
    ./llvm.sh 13 all; \
    ./llvm.sh 14 all; \
    rm -rf /var/lib/apt/lists/*

RUN set -x -e; \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -; \
    apt-add-repository -y -n 'https://apt.kitware.com/ubuntu/'; \
    apt-get -y update; \
    apt-get -y install --no-install-recommends \
        # build
        cmake pkg-config make ninja-build \
        # GCC compilers
        gcc-9 gcc-10 gcc-11 gcc-12 \
        g++-9 g++-10 g++-11 g++-12 \
        # Clang compilers (except ones installed by script above)
        clang-11 clang-12 \
        # Clang tools
        clang-tidy-11 clang-tidy-12 \
        clang-format-11 clang-format-12 \
        # LLVM
        llvm-11 llvm-12 \
        gcovr \
        # Coverage report upload
        curl \
        # ctest -D ExperimentalMemCheck
        valgrind \
        # Using boost as reference for tests
        libboost1.74-all-dev \
        # zlib needed for some boost components
        zlib1g-dev \
        # openssl needed for some users
        libssl-dev \
        # git for listing files in changes
        git \
        ; \
    rm -rf /var/lib/apt/lists/*

# x86 cross compilation
RUN set -x -e; \
    apt-get -y update; \
    apt-get -y install --no-install-recommends \
        g++-multilib \
        linux-libc-dev-i386-cross \
    ; \
    rm -rf /var/lib/apt/lists/*

# Cross compilation for Windows: MinGW, boost, zlib, OpenSSL
RUN set -x -e; \
    SOURCES_DIR="/home/sources"; \
    MINGW_PREFIX="x86_64-w64-mingw32"; \
    MINGW_PREFIX_DIR="/usr/${MINGW_PREFIX}"; \
    mkdir -p ${SOURCES_DIR}; \
    apt-get -y update; \
    apt-get -y install --no-install-recommends mingw-w64; \
    # Download packages
    wget -q https://boostorg.jfrog.io/artifactory/main/release/1.74.0/source/boost_1_74_0.tar.gz -P ${SOURCES_DIR}; \
    wget -q https://zlib.net/zlib-1.2.13.tar.gz -P ${SOURCES_DIR} ; \
    wget -q https://www.openssl.org/source/openssl-1.1.1h.tar.gz -P ${SOURCES_DIR} ; \
    # Extract packages
    for f in ${SOURCES_DIR}/*.tar.gz; do tar xf "$f" -C ${SOURCES_DIR}; done; \
    # Boost
    cd ${SOURCES_DIR}/boost*; \
    echo "using gcc : mingw : ${MINGW_PREFIX}-g++ ;" > ~/user-config.jam; \
    CC=gcc-10 CXX=g++-10 ./bootstrap.sh --prefix="${MINGW_PREFIX_DIR}" --with-toolset=gcc; \
    ./b2 toolset=gcc-mingw target-os=windows variant=release address-model=64 --without-python --without-context --without-coroutine install; \
    # zlib
    cd ${SOURCES_DIR}/zlib*; \
    make -j$(nproc) install -f win32/Makefile.gcc BINARY_PATH=${MINGW_PREFIX_DIR}/bin INCLUDE_PATH=${MINGW_PREFIX_DIR}/include LIBRARY_PATH=${MINGW_PREFIX_DIR}/lib SHARED_MODE=1 PREFIX=${MINGW_PREFIX}-; \
    # OpenSSL
    cd ${SOURCES_DIR}/openssl*; \
    ./Configure mingw64 shared --cross-compile-prefix=${MINGW_PREFIX}- --prefix="${MINGW_PREFIX_DIR}"; \
    make -j$(nproc); \
    make install_sw; \
    # Cleanup
    rm -rf "${SOURCES_DIR}" ~/user-config.jam; \
    rm -rf /var/lib/apt/lists/*

# Java
RUN set -x -e; \
    apt-get -y update; \
    apt-get -y install --no-install-recommends openjdk-11-jre-headless; \
    rm -rf get-pip.py /var/lib/apt/lists/*

# Python packages + Protobuf support for CMake based code generations
RUN set -x -e; \
    apt-get -y update; \
    apt-get -y install --no-install-recommends python3-distutils protobuf-compiler; \
    wget -q https://bootstrap.pypa.io/pip/3.6/get-pip.py; \
    python3 get-pip.py; \
    pip3 install dataclasses dataclasses_json Jinja2 protobuf pytest xmlschema lxml jsonschema; \
    rm -rf get-pip.py /var/lib/apt/lists/*

# Python 3.8
RUN set -x -e; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get -y update; \
    apt-get -y install --no-install-recommends python3.8 python3.8-distutils; \
    wget -q https://bootstrap.pypa.io/get-pip.py; \
    python3.8 get-pip.py; \
    python3.8 -m pip install dataclasses dataclasses_json Jinja2 protobuf pytest xmlschema lxml jsonschema; \
    rm -rf get-pip.py /var/lib/apt/lists/*

COPY entrypoint.py /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/bin/python3", "-u", "/usr/local/bin/entrypoint"]
