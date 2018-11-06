Jekyll::Hooks.register :site, :after_init  do |site|
  site.config['distros'] = site.config['ros2_distros'] +
                           site.config['ros_distros']
  site.config['old_distros'] = site.config['old_ros2_distros'] +
                               site.config['old_ros_distros']
end
