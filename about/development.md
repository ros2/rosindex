---
layout: page
title: Development
permalink: /about/development/
breadcrumbs: ['about']
---

# ROS Index Development

ROS Index is a statically-generated website which is composed of four main components:

1. A Jekyll backbone
2. A Jekyll Ruby plugin which clones and analyzes ROS repositories
3. HTML templates for displaying content
4. Build-side and client-side javascript for searching the index

Everything used to build ROS Index can be found on the
[rosindex repository](http://github.com/ros2/rosindex).

<a href="https://github.com/ros2/rosindex/issues/new" target="_blank" class="btn btn-success">Post an Issue</a>

{% toc 2 %}

## Building ROSIndex

See the [ROS Index README.md](http://github.com/ros2/rosindex)
for details on building ROS Index locally.

## Design Patterns

### Pagination

Currently, pagination of `N` total items is done by generating html files for
each page of `n` items and each `m` ways of sorting those items. This leads to
`n*(m+1)` html pages (`+1` for the default sort, whichever that may be). This
also constrains the display to display only `N/n` items at a time.
