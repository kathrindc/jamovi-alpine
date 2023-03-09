FROM alpine:latest AS base
FROM jamovi-base:local as r-base

FROM r-base AS server
RUN apk update && \
	apk add \
		gcc \
		g++ \
		make \
		alpine-sdk \
		python3-dev \
		python3

ARG JAMOVI_ROOT=jamovi
ARG MODS_ROOT=$JAMOVI_ROOT/docker/mods

COPY $JAMOVI_ROOT/docker/requirements.txt $MODS_ROOT/server/requirements.tx[t] /tmp/source/
WORKDIR /tmp/source
RUN python3 -m pip install --trusted-host pypi.python.org -r requirements.txt

COPY $JAMOVI_ROOT/readstat /tmp/source/readstat
WORKDIR /tmp/source/readstat
RUN python3 setup.py install --install-lib=/usr/lib/jamovi/server

COPY $JAMOVI_ROOT/server $MODS_ROOT/server /tmp/source/server
WORKDIR /tmp/source/server
RUN python3 setup.py install --install-lib=/usr/lib/jamovi/server

COPY $JAMOVI_ROOT/platform/env.conf /usr/lib/jamovi/bin/



FROM r-base AS client
RUN apk update && \
	apk add \
		nodejs \
		npm

ARG JAMOVI_ROOT=jamovi
ARG MODS_ROOT=$JAMOVI_ROOT/docker/mods

COPY $JAMOVI_ROOT/client/package.json $MODS_ROOT/client/package.jso[n] /tmp/source/client/
WORKDIR /tmp/source/client
RUN npm install
RUN mkdir -p /usr/lib/jamovi/client

COPY $JAMOVI_ROOT/client/ /tmp/source/client/
COPY $MODS_ROOT/client/ /tmp/source/client/
COPY $JAMOVI_ROOT/server/jamovi/server/jamovi.proto /tmp/source/client/assets/coms.proto
RUN node_modules/.bin/vite build --outDir /usr/lib/jamovi/client
COPY $JAMOVI_ROOT/version /usr/lib/jamovi/client



FROM r-base AS engine
RUN apk update && \
	apk add \
		gcc \
		g++ \
		make \
		alpine-sdk \
		python3-dev \
		python3 \
		R-dev \
		asio \
		asio-dev \
		libexecinfo \
		libexecinfo-dev

ARG JAMOVI_ROOT=jamovi

COPY $JAMOVI_ROOT/engine /tmp/source/engine
COPY $JAMOVI_ROOT/server/jamovi/common /tmp/source/server/jamovi/common
COPY $JAMOVI_ROOT/server/jamovi/server/jamovi.proto /tmp/source/server/jamovi/server/jamovi.proto
WORKDIR /tmp/source/engine

RUN sh configure --rhome=$R_HOME \
	--base-module-path=$R_HOME/library \
	--rpath=$R_HOME/library/RInside/lib \
	--rpath=$R_HOME/lib \
	CXXFLAGS="-DJAMOVI_ENGINE_SUPPORT_LOCAL_SOCKETS -I/usr/include/R -lexecinfo"
RUN make
RUN DESTDIR=/usr/lib/jamovi make install



FROM r-base AS jmvcore

ARG JAMOVI_ROOT=jamovi

RUN mkdir -p /usr/lib/jamovi/modules/base/R
COPY $JAMOVI_ROOT/jmvcore /tmp/source/jmvcore
RUN R CMD INSTALL /tmp/source/jmvcore --library=/usr/lib/jamovi/modules/base/R
ENV R_LIBS /usr/lib/jamovi/modules/base/R



FROM jmvcore AS compiler
RUN apk update && \
	apk add \
		nodejs \
		npm \
		git \
		bash

COPY --from=server /usr/lib/jamovi /usr/lib/jamovi

ARG JAMOVI_ROOT=jamovi

COPY $JAMOVI_ROOT/version /usr/lib/jamovi
COPY $JAMOVI_ROOT/platform/env.conf /usr/lib/jamovi/bin
COPY $JAMOVI_ROOT/platform/jamovi /usr/lib/jamovi/bin
RUN chmod u+x /usr/lib/jamovi/bin/jamovi

COPY $JAMOVI_ROOT/jamovi-compiler /tmp/source/jamovi-compiler
RUN rm -f /tmp/source/jamovi-compiler/snapshots.js
COPY ./snapshots-patched.js /tmp/source/jamovi-compiler/snapshots.js
WORKDIR /tmp/source/jamovi-compiler
RUN npm install && npm install -g



FROM compiler AS jmv

ARG JAMOVI_ROOT=jamovi

COPY $JAMOVI_ROOT/jmv/ /tmp/source/jmv
WORKDIR /tmp/source/jmv
RUN jmc --install . --to /usr/lib/jamovi/modules --home /usr/lib/jamovi --rhome $R_HOME --rlibs /usr/lib/jamovi/modules/base/R --patch-version --skip-deps



FROM compiler AS extras

ARG JAMOVI_ROOT=jamovi

COPY $JAMOVI_ROOT/scatr /tmp/source/scatr
WORKDIR /tmp/source/scatr
RUN jmc --install . --to /usr/lib/jamovi/modules --home /usr/lib/jamovi --rhome $R_HOME --rlibs /usr/lib/jamovi/modules/base/R

WORKDIR /tmp/source
RUN git clone https://github.com/raviselker/surveymv.git
RUN jmc --install surveymv --to /usr/lib/jamovi/modules --home /usr/lib/jamovi --rhome $R_HOME --rlibs /usr/lib/jamovi/modules/base/R
RUN git clone https://github.com/davidfoxcroft/lsj-data.git /usr/lib/jamovi/modules/lsj-data
RUN git clone https://github.com/jamovi/r-datasets.git /usr/lib/jamovi/modules/r-datasets



FROM base AS i18n
RUN apk update && \
	apk add \
		nodejs \
		npm

RUN mkdir -p /usr/lib/jamovi/i18n/json

ARG JAMOVI_ROOT=jamovi

COPY $JAMOVI_ROOT/i18n /tmp/source/i18n
WORKDIR /tmp/source/i18n
RUN npm install
RUN node /tmp/source/i18n/index.js --build src --dest /usr/lib/jamovi/i18n/json



FROM r-base AS jamovi

RUN apk update && \
	apk add \
		python3 \
		icu \
		icu-libs \
		icu-dev \
		libgomp \
		libgfortran \
		curl \
		libcurl \
		curl-dev \
		libpng \
		libpng-dev \
		libjpeg \
		jpeg \
		jpeg-dev \
		cairo \
		cairo-dev \
		cairo-tools \
		harfbuzz \
		harfbuzz-dev \
		harfbuzz-icu \
		fribidi \
		fribidi-dev \
		tiff \
		tiff-dev \
		readline \
		readline-dev

COPY --from=jmv     /usr/lib/jamovi/ /usr/lib/jamovi/
COPY --from=extras  /usr/lib/jamovi/ /usr/lib/jamovi/
COPY --from=server  /usr/lib/jamovi/ /usr/lib/jamovi/
COPY --from=server  /usr/lib/python3.10/ /usr/lib/python3.10/
COPY --from=server  /usr/local/lib/cmake/nanomsg* /usr/local/lib/cmake/
COPY --from=server  /usr/local/lib/pkgconfig/nanomsg* /usr/local/lib/pkgconfig/
COPY --from=server  /usr/local/lib/libnanomsg* /usr/local/lib/
COPY --from=server  /usr/local/include/nanomsg /usr/local/include/
COPY --from=client  /usr/lib/jamovi/client/ /usr/lib/jamovi/client/
COPY --from=i18n    /usr/lib/jamovi/i18n/json /usr/lib/jamovi/i18n/json
COPY --from=engine  /usr/lib/jamovi/bin/jamovi-engine /usr/lib/jamovi/bin/jamovi-engine

ENV LD_LIBRARY_PATH $R_HOME/lib
ENV JAMOVI_HOME /usr/lib/jamovi
ENV PYTHONPATH /usr/lib/jamovi/server
ENV R_LIBS $R_HOME/library
ENV JAMOVI_SESSION_EXPIRES 0
ENV JAMOVI_ALLOW_ARBITRARY_CODE false

EXPOSE 41337
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/usr/bin/python3 -m jamovi.server 41337 --if=*"]

