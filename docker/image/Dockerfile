FROM ubuntu:bionic

ARG user=rosindex
ARG uid=1000

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        gnupg && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb http://packages.ros.org/ros/ubuntu xenial main" > \
         /etc/apt/sources.list.d/ros-latest.list
RUN sudo apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 \
         --recv-key 421C365BD9FF1F717815A3895523BAEEB01FA116

RUN echo 'deb http://archive.ubuntu.com/ubuntu/ cosmic universe\n' >> \
        /etc/apt/sources.list
RUN echo 'Package: *\n\
Pin: release n=cosmic\n\
Pin-Priority: -10\n\
\n\
Package: pandoc*\n\
Pin: release n=cosmic\n\
Pin-Priority: 500\n\
' > /etc/apt/preferences.d/cosmic.pref

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
        libz-dev \
        mercurial \
        nodejs \
        openssl \
        pandoc \
        pkg-config \
        python-pip \
        python3-pip \
        python3-vcstool \
        ruby \
        ruby-dev \
        rubygems-integration && \
    rm -rf /var/lib/apt/lists/*

RUN gem install bundle
RUN pip install --upgrade setuptools pip
RUN pip install recommonmark==0.4 sphinx==1.5.6
RUN pip3 install --upgrade pip
RUN pip3 install gitpython

RUN ln -s `which nodejs` /usr/local/bin/node

COPY docker/image/build_site.sh /usr/local/bin/build_site
COPY docker/image/test_site.sh /usr/local/bin/test_site
COPY docker/image/update_site.sh /usr/local/bin/update_site
COPY docker/image/git_add_files.py /usr/local/bin/git_add_files

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

# The environment variables REPO and SITE should be set when running this container.
# REPO: The path to this source repository in the container
# SITE: The path to the destination repository in the container
ENV REPO ""
ENV SITE ""
CMD update_site ${REPO} ${SITE}
