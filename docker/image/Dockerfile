FROM ubuntu:xenial

ARG user=rosindex
ARG uid=1000

ENV DEBIAN_FRONTEND noninteractive

RUN echo "deb http://packages.ros.org/ros/ubuntu xenial main" > \
         /etc/apt/sources.list.d/ros-latest.list
RUN apt-key adv --keyserver hkp://pool.sks-keyservers.net --recv-key 0xB01FA116

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        apt-utils \
        build-essential \
        cmake \
        curl \
        git-all \
        git-svn \
        libgit2-dev \
        libpthread-stubs0-dev \
        libssl-dev \
        libsslcommon2-dev \
        libz-dev \
        mercurial \
        nodejs \
        openssl \
        pandoc \
        pkg-config \
        python-pip \
        python3-vcstool \
        ruby \
        ruby-dev \
        rubygems-integration && \
    rm -rf /var/lib/apt/lists/*

RUN gem install bundle
RUN pip install --upgrade setuptools pip
RUN pip install recommonmark==0.4 sphinx==1.5.6

RUN ln -s `which nodejs` /usr/local/bin/node

COPY docker/image/build_site.sh /usr/local/bin/build_site
COPY docker/image/test_site.sh /usr/local/bin/test_site
COPY docker/image/update_site.sh /usr/local/bin/update_site

RUN useradd -u $uid -m $user
ENV HOME=/home/$user
WORKDIR $HOME
COPY Gemfile* .bundle/
RUN chown -R $user:$user .

USER $user
ENV BUNDLE_PATH=$HOME/.bundle
ENV BUNDLE_GEMFILE=$HOME/.bundle/Gemfile
RUN bundle install

RUN git config --global user.name "rosindex"
RUN git config --global user.email "rosindex@build.ros.org"

CMD update_site ${REPO} ${SITE}
