# Copy the specified documentation repos into the
# jekyll-tracked "doc" directory.
require 'fileutils'

Jekyll::Hooks.register :site, :after_init do |site|
    site.config['docs_repos'].each do |repo|
        src = File.join(site.source, "_remotes", repo["name"])
        dest_dir = File.join(site.source, "doc")
        dest = File.join(dest_dir, repo["name"])
        if File.directory?(dest)
          FileUtils.rm_r(dest)
        end
        if File.directory?(src)
            FileUtils.cp_r(src, dest_dir)
        else
            raise IOError.new("Unable to copy from #{src}, the directory doesn't exist.")
        end
    end
end
