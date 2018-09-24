# Copy the specified documentation repos into the
# jekyll-tracked "doc" directory.

require 'fileutils'

Jekyll::Hooks.register :site, :after_init do |site|
    site.config['documentation_repos'].each do |repo_dir|
        origin = File.join(site.source, "_remotes", repo_dir)
        dest = File.join(site.source, "doc") 
        to_delete = File.join(site.source, repo_dir) 
        if File.directory?(to_delete)
            FileUtils.rm_r(to_delete)
        end
        if File.directory?(origin)
            FileUtils.cp_r(origin, dest)
        else
            raise IOError.new("Unable to copy from #{origin}, the directory doesn't exist.")
        end
    end
end
