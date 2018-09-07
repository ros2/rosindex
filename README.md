ROS Index
=========

A simple static index for known ROS packages. It builds in jekyll with a plugin
to clone repositories containing ROS packages, scrapes them for information,
and uses client-side javascript for quick searching and visualization.

[ROS Index](http://rosindex.github.io/)

* [About](http://rosindex.github.io/about)
* [Design](http://rosindex.github.io/about/design)
* [Development](http://rosindex.github.io/about/development)
* [Contribute](http://rosindex.github.io/contribute)

[![Stories in Ready](https://badge.waffle.io/rosindex/rosindex.svg?label=ready&title=Ready)](http://waffle.io/rosindex/rosindex)

## Building

### Pre-Requisites

#### Basic Ubuntu 16.04 Deps

```
echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list
apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-key 421C365BD9FF1F717815A3895523BAEEB01FA116
sudo apt-get update
sudo apt-get install curl git git-svn mercurial nodejs pandoc python3-vcs
```

#### Ruby 2.2 via RVM

```
curl -L https://get.rvm.io | bash -s stable
# if this fails, add the PGP key and run again
source ~/.rvm/scripts/rvm
rvm requirements
rvm install ruby
rvm rubygems current
```

#### Node.js on Ubuntu 12.04

```
sudo apt-get install python-software-properties
sudo apt-add-repository ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get install nodejs
```

#### Ruby Requirements

```
gem install bundler
```

#### Clone Source and Install Gems

```
git clone git@github.com:ros2/rosindex.git --recursive
cd rosindex.github.io
bundle install
```

### Clone repos that are part of rosdistro and build the index

```
make build
```

### Serve the devel (tiny) version locally

```
make serve-devel
```

### Serve the full version locally

**Note:** This requires a minimum of 30GB of
free space for the `checkout` directory.

```
make serve
```

### Skipping Parts of the Build

The build process entails four long-running steps:

1. Generating the list of repositories
2. Cloning / Updating the known repositories
3. Scraping the repositories
4. Generating the static pages
5. Generating the lunr search index

Each of the first three steps can be skipped in order to save time when
experimenting with different parts of the pipeline with the following flags in
`_config.yml`:

```yaml
# If true, this skips finding repos based on the repo sources
skip_discover: false
# If true, this skips updating the known repos
skip_update: false
# If true, this skips scraping the cloned repos
skip_scrape: false
# If true, this skips generating the search index
skip_search_index: false
```

## Deployment

Deployment is done by calling the following make command:

```
make deploy
```
