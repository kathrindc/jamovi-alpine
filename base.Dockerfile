FROM alpine:latest

MAINTAINER Kathrin De Cecco <kad@toast.ws>

ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
ENV TZ UTC

ENV BUILD_DEPS \
	cairo-dev \
	libxmu-dev \
	openjdk8-jre-base \
	pango-dev \
	perl \
	tiff-dev \
	tk-dev

ENV PERSISTENT_DEPS \
	R-mathlib \
	gcc \
	gfortran \
	icu-dev \
	libjpeg-turbo \
	libpng-dev \
	make \
	openblas-dev \
	pcre-dev \
	readline-dev \
	xz-dev \
	zlib-dev \
	bzip2-dev \
	curl-dev \
	curl \
	pandoc

RUN apk upgrade --update && \
	apk add --no-cache --virtual .build-deps $BUILD_DEPS && \
	apk add --no-cache --virtual .persistent-deps $PERSISTENT_DEPS && \
	apk add --no-cache R R-dev && \
	apk del .build-deps

RUN curl -sL "https://yihui.org/tinytex/install-bin-unix.sh" | sh
RUN tlmgr install collection-fontsrecommended


