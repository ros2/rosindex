from ubuntu:xenial

RUN echo "deb http://packages.ros.org/ros/ubuntu xenial main" > /etc/apt/sources.list.d/ros-latest.list
RUN apt-key adv --keyserver hkp://pool.sks-keyservers.net --recv-key 0xB01FA116

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        apt-utils \
        build-essential \
        bundler \
        cmake \
        curl \
        git-all \
        git-svn \
        libgit2-dev \
        libpthread-stubs0-dev \
        libssh-dev \
        libssh2-1 \
        libssh2-1-dev \
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
        rubygems-integration \
        ssh \
        sudo \
        tmux && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade setuptools pip &&
    pip install \
        recommonmark=0.4 \
        sphinx==1.5.6 \
        sphinx-markdown-tables

RUN ln -s `which nodejs` /usr/local/bin/node

#RUN curl -sSL https://rvm.io/mpapis.asc | gpg --import -
#RUN curl -L https://get.rvm.io | bash -s stable

#RUN . /usr/local/rvm/src/rvm/scripts/rvm
#RUN echo "source /usr/local/rvm/src/rvm/scripts/rvm" >> ~/.bashrc

#RUN /usr/local/rvm/src/rvm/bin/rvm requirements
#RUN /usr/local/rvm/src/rvm/bin/rvm install ruby
#RUN /usr/local/rvm/src/rvm/bin/rvm rubygems current

#RUN apt-get install -y python-software-properties
#RUN apt-add-repository -y ppa:chris-lea/node.js
#RUN apt-get update
#RUN apt-get install nodejs

VOLUME /workdir

RUN mkdir /root/.ssh && \
    touch /root/.ssh/known_hosts && \
    ssh-keyscan github.com >> /root/.ssh/known_hosts && \
    ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts

WORKDIR /workdir
COPY Gemfile /workdir
RUN bundle install

WORKDIR /workdir/rosindex
