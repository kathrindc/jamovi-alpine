FROM --platform=$TARGETPLATFORM alpine:latest

MAINTAINER Kathrin De Cecco <kad@toast.ws>

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV TZ=UTC

ENV BUILD_DEPS \
	cmake \
	cairo-dev \
	libxmu-dev \
	openjdk8-jre-base \
	pango-dev \
	perl \
	tiff-dev \
	tk-dev \
	alpine-sdk \
	cabal \
	coreutils \
	ghc \
	libffi \
	musl-dev \
	linux-headers

ENV PERSISTENT_DEPS \
	R-mathlib \
	gcc \
	g++ \
	gfortran \
	icu-dev \
	libjpeg-turbo \
	libpng-dev \
	libprotoc \
	make \
	openblas-dev \
	pcre-dev \
	readline-dev \
	xz-dev \
	zlib-dev \
	bzip2-dev \
	curl-dev \
	curl \
	gmp \
	gmp-dev \
	libxml2-dev \
	libxml2 \
	glpk \
	glpk-dev \
	graphviz \
	openjdk11-jre \
	python3 \
	py3-pip \
	sed \
	ttf-droid \
	ttf-droid-nonlatin \
	wget \
	perl-switch \
	fontconfig \
	fontconfig-dev \
	gpg \
	libprotobuf \
	protobuf \
	protobuf-dev \
	protobuf-c \
	protobuf-c-dev \
	boost1.78\
	boost1.78-dev \
	boost1.78-filesystem \
	boost1.78-system

RUN apk upgrade --update && \
	apk add --no-cache --virtual .build-deps $BUILD_DEPS && \
	apk add --no-cache --virtual .persistent-deps $PERSISTENT_DEPS

RUN cabal v2-update

RUN apk add --no-cache R R-dev

RUN cabal install pandoc-cli && \
	mv /root/.cabal/bin/pandoc /usr/bin/pandoc && \
	rm -Rf /root/.cabal /root/.ghc

RUN mkdir -p /usr/share/doc/R/html

RUN wget -qO- \
		"https://github.com/yihui/tinytex/raw/main/tools/install-unx.sh" | \
        sh -s - --admin --no-path && \
		mv ~/.TinyTeX /opt/tinytex && \
		/opt/tinytex/bin/*/tlmgr path add && \
		tlmgr path add && \
		chown -R root:adm /opt/tinytex && \
		chmod -R g+w /opt/tinytex && \
		chmod -R g+wx /opt/tinytex/bin

RUN tlmgr install collection-fontsrecommended

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

ENV R_HOME=/usr/lib/R
ENV CRAN_MIRROR=https://packagemanager.rstudio.com/cran/latest
RUN echo "options(repos=c(pm='$CRAN_MIRROR'), Ncpus=12)" > $R_HOME/etc/Rprofile.site

RUN MAKEFLAGS=-j20 R -e "\
    packages <- c('R6','RColorBrewer','base64enc','brio','cpp11','curl','farver','fastmap','magrittr','praise','rprojroot','rstudioapi','utf8','viridisLite','yaml','Rcpp','colorspace','crayon','digest','evaluate','fansi','glue','gtable','isoband','jsonlite','labeling','pkgconfig','ps','remotes','rlang','stringi','systemfonts','withr','xfun','RInside','RProtoBuf','cli','desc','diffobj','ellipsis','highr','htmltools','lifecycle','munsell','processx','stringr','textshaping','tinytex','callr','jquerylib','knitr','pkgload','ragg','scales','vctrs','pillar','rmarkdown','tibble','ggplot2','rematch2','waldo','testthat'); \
    install.packages(                 \
        packages,                     \
        depends=FALSE,                \
        lib='$R_HOME/library',        \
        INSTALL_opts='--no-data --no-help --no-demo --no-html --no-docs --no-multiarch --clean'); \
    for (pkg in packages) {               \
        library(pkg, character.only=TRUE); \
    }"

RUN MAKEFLAGS=-j20 R -e "\
    packages <- c('GPArotation','RcppParallel','SQUAREM','backports','bitops','ca','carData','contfrac','glasso','gower','jpeg','lisrelToR','listenv','matrixStats','nloptr','numDeriv','pbivnorm','png','prettyunits','qvcalc','tmvnsim','truncnorm','zip','Formula','MatrixModels','PMCMR','RUnit','RcppArmadillo','RcppEigen','Rsolnp','SparseM','TH.data','XML','abind','caTools','checkmate','coda','corpcor','data.table','deSolve','elliptic','estimability','fdrtool','forcats','generics','ggrepel','globals','gridExtra','gtools','hms','htmlwidgets','igraph','iterators','latticeExtra','minqa','mnormt','mvnormtest','mvtnorm','openxlsx','parallelly','pbapply','plyr','progressr','proxy','purrr','relimp','sp','ssanv','timeDate','xtable','zoo','ModelMetrics','e1071','emmeans','exactci','foreach','future','ggridges','gnm','gplots','htmlTable','hypergeo','kutils','lavaan','lme4','lmtest','lubridate','maptools','pROC','progress','psych','reshape','reshape2','rpf','sandwich','tidyselect','viridis','BayesFactor','Hmisc','OpenMx','ROCR','arm','dplyr','exact2x2','future.apply','lmerTest','multcomp','regsem','rockchalk','vcd','lava','mi','qgraph','tidyr','vcdExtra','GGally','broom','prodlim','sem','ipred','pbkrtest','semPlot','recipes','caret','conquer','quantreg','car','afex'); \
        install.packages(                 \
            packages,                     \
            depends=FALSE,                \
            lib='$R_HOME/library',        \
            INSTALL_opts='--no-data --no-help --no-demo --no-html --no-docs --no-multiarch --clean'); \
    for (pkg in packages) {               \
        library(pkg, character.only=TRUE); \
    }"

WORKDIR /tmp/source
RUN curl -sL "https://github.com/nanomsg/nanomsg/archive/refs/tags/1.2.tar.gz" | tar -xzf -
WORKDIR /tmp/source/nanomsg-1.2
RUN mkdir build && \
	cd build && \
	cmake .. && \
	cmake --build . && \
	ctest . && \
	cmake --build . --target install

WORKDIR /
RUN rm -Rf /tmp/source
RUN apk del .build-deps

