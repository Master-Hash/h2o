FROM chimeralinux/chimera AS builder
# FROM ghcr.io/eweos/docker:master AS builder
# FROM alpine:edge AS builder

# alpine
# RUN apk update \
#     && apk add build-base clang mold cmake pkgconf zlib-ng-dev wslay-dev make perl \
#     libuv-dev linux-headers openssl-dev zlib-dev brotli-dev

# chimera
RUN apk update \
    && apk add base-devel clang mold cmake pkgconf zlib-ng-devel wslay-devel gmake perl ninja linux-headers

# eweos
# 不存在 wslay
# RUN pacman -Syu --noconfirm \
#     base-devel libuv linux-headers

ENV CC=clang
ENV CXX=clang++

WORKDIR /usr/src/boringssl
COPY ./boringssl/ .

RUN cmake -GNinja -B build -DBUILD_SHARED_LIBS=1 \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_C_FLAGS="-march=x86-64-v3 -flto=thin -fvisibility=hidden -fno-rtti -fno-exceptions" \
    -DCMAKE_CXX_FLAGS="-march=x86-64-v3 -flto=thin -fvisibility=hidden -fno-rtti -fno-exceptions" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--strip-debug" \
    -DCMAKE_LINKER=/usr/bin/ld.mold -DCMAKE_BUILD_TYPE=Release

RUN ninja -C build

RUN ninja -C build install

# 实际上是可以动态加载 bssl 的
# 但这是 Docker，这没什么必要。
# 但是可以让容器更小一点，如果不删除 .a 之类的文件。
RUN cmake -GNinja -B build -DBUILD_SHARED_LIBS=0 \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_C_FLAGS="-march=x86-64-v3 -flto=thin -fvisibility=hidden -fno-rtti -fno-exceptions" \
    -DCMAKE_CXX_FLAGS="-march=x86-64-v3 -flto=thin -fvisibility=hidden -fno-rtti -fno-exceptions" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--strip-debug" \
    -DCMAKE_LINKER=/usr/bin/ld.mold -DCMAKE_BUILD_TYPE=Release

RUN ninja -C build \
    && cp build/decrepit/libdecrepit.a /usr/local/lib/


WORKDIR /usr/src/h2o
COPY . .

RUN mkdir build \
    && cd build \
    && cmake .. -DWITH_MRUBY=off -DWITH_DTRACE=off -DWITH_H2OLOG=off \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DOPENSSL_ROOT_DIR=/usr/local \
    -DCMAKE_C_FLAGS="-march=x86-64-v3 -flto=thin -fvisibility=hidden -fno-rtti -fno-exceptions" \
    -DCMAKE_CXX_FLAGS="-march=x86-64-v3 -flto=thin -fvisibility=hidden -fno-rtti -fno-exceptions" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--strip-debug" \
    -DCMAKE_LINKER=/usr/bin/ld.mold -DCMAKE_BUILD_TYPE=Release \
    # && cat CMakeCache.txt \
    && make -j8 VERBOSE=1 && make install

FROM chimeralinux/chimera
# FROM ghcr.io/eweos/docker:master

RUN apk upgrade --no-cache && apk add --no-cache \
    perl

COPY --link --from=builder /usr/local/ /usr/local/
COPY --link ./h2o.conf /usr/local/etc/h2o.conf


CMD ["h2o"]
