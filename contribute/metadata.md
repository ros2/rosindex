---
layout: page
title: ROS Index Metadata
permalink: /contribute/metadata/
breadcrumbs: ['contribute']
---

# ROS Index Metadata

{% toc 2 %}

## Adding Package Metadata

Catkin `package.xml` and ROSBuild `manifest.xml` files can be augmented with
`<rosindex>` tags in the `<export>` section, which is meant for 3rd-party use.
Adding an empty rosindex section to a `package.xml` file would look like the
following:

```xml
<package>
  <!-- required metadata -->

  <!-- ... -->

  <export>
    <rosindex>
      <!-- rosindex-related tags -->
    </rosindex>
  </export>
</package>
```

The metadata described in the following sections must all be added under
a single `<rosindex></rosindex>` tag.

## Metadata Elements

The following are accepted ROS Index metadata elements for further describing
a ROS package:

* **Category Tags** -- `<tags>...</tags>`
* **Alternate README** -- `<readme>...</readme>`

The following are ROS Index metadata elements which are either unimplemented or
still being designed:

* **Tutorials** -- `<tutorials>...</tutorials>`
* **Nodes** -- `<nodes>...</nodes>`

### Category Tags

Tags are useful for categorizing related ROS packages in rosindex. They are
single words or multiple hyphenated words.

For example, adding the tags `biped`, `planning`, and `real-time` in the
rosindex section would look like the following:

```xml
<tags>
  <tag>biped</tag>
  <tag>planning</tag>
  <tag>real-time</tag>
</tags>
```

### Include Other XML File

***UNIMPLEMENTED***

If you don't want to put all the ROS Index metadata into your package manifest,
you can use a `<rosindex file="..."/>` tag to include other XML sources from
within the package.

```xml
<package>
  <!-- required metadata -->

  <!-- ... -->

  <export>
    <!-- Include another xml file relative to the package.xml path -->
    <rosindex file="doc/rosindex_metadata.xml"/>
  </export>
</package>
```

### Alternate README

***UNIMPLEMENTED***

By default, rosindex will assume that the readme file for a repository or
package is placed in the package root. If not, a `<readme></readme>` tag can be
used to specify an alternative.

For example, an alternative readme, stored in a `doc` subdirectory, could be
specified like the following:

```xml
<readme>doc/README.md</readme>
```

Standard readme filenames include (case-insensitive):

* `README`
* `README.txt`
* `README.md`
* `README.rst`

Plaintext files and files without extensions will not be rendered, but will be
shown as a single preformatted block. Markdown (`.md`) and RST (`.rst`)
documents will be rendered into HTML.

### Tutorials

***WIP***

A package can give a list of a series of tutorials with the
following formats:

```xml
<tutorials>
  <!-- Declare some pre-requisite tutorials -->
  <prereq pkg="other_pkg"/>

  <!-- Direct users to another package for tutorials. -->
  <tutorial pkg="my_pkg_tutorials"/>

  <!-- Direct users to a tutorial on an external website. -->
  <tutorial link="http://www.my_website.com/some_tutorial.html">That Other Guy's Tutorial</tutorial>

  <!-- Display markdown-based tutorials (rendered by ROSIndex). -->
  <tutorial file="doc/tut1.md">Tutorial One</tutorial>
  <tutorial file="doc/tut2.md">Tutorial Two</tutorial>
  <tutorial file="doc/tut3.md">Tutorial Three</tutorial>

  <!-- Display a group of markdown-based tutorials (rendered by ROSIndex). -->
  <sequence title="Advanced Tutorials">
    <tutorial file="doc/tut4.md">Tutorial Four</tutorial>
    <tutorial file="doc/tut5.md">Tutorial Five</tutorial>
    <tutorial file="doc/tut6.md">Tutorial Six</tutorial>
  </sequence>
</tutorials>
```

Tutorials listed on the ROS Wiki under `<<package_name>>/Tutorials/*`
will also be listed and directly linked.

### Nodes

***WIP***

Similar to the ROS wiki, this describes the available ROS nodes in the package,
along with their ROS interfaces. Note the `<ros_api>` element. This element
schema could be re-used to describe libraries and nodelets (and whatever future
ROS API units we have) as well.

#### Using the XML Schema

```xml
<nodes>
  <node>
    <name>cameracalibrator.py</name>
    <description format="md">
      `cameracalibrator.py` subscribes to ROS raw image topics, and presents a
      calibration window.  It can run in both monocular and stereo modes. The
      calibration window shows the current images from the cameras, highlighting
      the checkerboard.  When the user presses the `CALIBRATE` button, the
      node computes the camera calibration parameters.  When the user clicks
      `COMMIT`, the node uploads these new calibration parameters to the
      camera driver using a service call.
    </description>

    <ros_api>
      <sub name="image" type="sensor_msgs/Image">raw image topic, for monocular cameras</sub>
      <sub name="left" type="sensor_msgs/Image">raw left image topic, for stereo cameras</sub>
      <sub name="right" type="sensor_msgs/Image">raw right image topic, for stereo cameras</sub>

      <srv_called name="camera/set_camera_info" type="sensor_msgs/SetCameraInfo">
        Sets the camera info for a monocular camera
      </srv_called>
      <srv_called name="left_camera/set_camera_info" type="sensor_msgs/SetCameraInfo">
        Sets the camera info for the left camera of a setereo pair
      </srv_called>
      <srv_called name="right_camera/set_camera_info" type="sensor_msgs/SetCameraInfo">
        Sets the camera info for the right camera of a setereo pair
      </srv_called>
    </ros_api>
  </node>
</nodes>
```

#### Using the same ClearSilver API used by the ROS wiki

See [rosindex.github.io#85](https://github.com/rosindex/rosindex/issues/85)

```xml
<nodes format="hdf">
    node.0 {
      name=cameracalibrator.py
      desc=`cameracalibrator.py` subscribes to ROS raw image topics, and presents a calibration window.  It can run in both monocular and stereo modes. The calibration window shows the current images from the cameras, highlighting the checkerboard.  When the user presses the '''CALIBRATE''' button, the node computes the camera calibration parameters.  When the user clicks '''COMMIT''', the node uploads these new calibration parameters to the camera driver using a service call.

      sub{
        0.name= image
        0.type= sensor_msgs/Image
        0.desc= raw image topic, for monocular cameras
        1.name= left
        1.type= sensor_msgs/Image
        1.desc= raw left image topic, for stereo cameras
        2.name= right
        2.type= sensor_msgs/Image
        2.desc= raw right image topic, for stereo cameras
      }
      srv_called{
        0.name= camera/set_camera_info
        0.type= sensor_msgs/SetCameraInfo
        0.desc= Sets the camera info for a monocular camera
        1.name= left_camera/set_camera_info
        1.type= sensor_msgs/SetCameraInfo
        1.desc= Sets the camera info for the left camera of a stereo pair
        2.name= right_camera/set_camera_info
        2.type= sensor_msgs/SetCameraInfo
        2.desc= Sets the camera info for the right camera of a stereo pair
      }
    }
</nodes>
```
