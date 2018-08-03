# encoding: UTF-8

# NOTE: This whole file is one big hack. Don't judge.

require 'pp'
require 'awesome_print'
require 'colorator'
require 'fileutils'
require 'find'
require 'rexml/document'
require 'rexml/xpath'
require 'pathname'
require 'json'
require 'uri'
require 'set'
require 'yaml'
require "net/http"
require 'thread'

# local libs
require_relative '../_ruby_libs/common'
require_relative '../_ruby_libs/rosindex'
require_relative '../_ruby_libs/vcs'
require_relative '../_ruby_libs/conversions'
require_relative '../_ruby_libs/text_rendering'
require_relative '../_ruby_libs/pages'
require_relative '../_ruby_libs/asset_parsers'
require_relative '../_ruby_libs/roswiki'

$fetched_uris = {}
$debug = false

def get_ros_api(elem)
  return []
end

def get_readme(site, path, raw_uri)
  return get_md_rst_txt(site, path, "README*", raw_uri)
end

def get_changelog(site, path, raw_uri)
  return get_md_rst_txt(site, path, "CHANGELOG*", raw_uri)
end

# Get a raw URI from a repo uri
def get_raw_uri(uri_s, type, branch)
  uri = URI(uri_s)

  case uri.host
  when 'github.com'
    uri_split = File.split(uri.path)
    path_split = uri_split[1].rpartition('.')
    repo_name = if path_split[1] == '.' then path_split[0] else path_split[-1] end
    return 'https://raw.githubusercontent.com/%s/%s/%s' % [uri_split[0], repo_name, branch]
  when 'bitbucket.org'
    uri_split = File.split(uri.path)
    return 'https://bitbucket.org/%s/%s/raw/%s' % [uri_split[0], uri_split[1], branch]
  when 'code.google.com'
    uri_split = File.split(uri.path)
    return "https://#{uri_split[1]}.googlecode.com/#{type}-history/#{branch}/"
  end

  return uri_s
end

# Get a browse URI from a repo uri
def get_browse_uri(uri_s, type, branch)
  uri = URI(uri_s)

  case uri.host
  when 'github.com'
    uri_split = File.split(uri.path)
    path_split = uri_split[1].rpartition('.')
    repo_name = if path_split[1] == '.' then path_split[0] else path_split[-1] end
    return 'https://github.com/%s/%s/tree/%s' % [uri_split[0], repo_name, branch]
  when 'bitbucket.org'
    uri_split = File.split(uri.path)
    return 'https://bitbucket.org/%s/%s/src/%s' % [uri_split[0], uri_split[1], branch]
  when 'code.google.com'
    uri_split = File.split(uri.path)
    return "https://code.google.com/p/#{uri_split[1]}/source/browse/?name=#{branch}##{type}/"
  end

  return uri_s
end

def resolve_dep(ps, ms, os, ver, data)
  # resolve rosdep
  # ps: platforms
  # ms: package managers
  # os: desired os
  # ver: desired os version
  # data: yaml data

  if data.is_a?(Array) then return data end
  if data.is_a?(Hash)
    if data.key?(os) then return resolve_dep(ps, ms, os, ver, data[os]) end
    if data.key?(ver) then return resolve_dep(ps, ms, os, ver, data[ver]) end
    if data.key?('source') and data['source'].key?('uri') then return data['source']['uri'] end
    if data.key?('packages') then return data['packages'] end
    ms.each do |manager_name, manager_oss|
      if ((manager_oss.include?(os) or manager_oss.size == 0) and data.key?(manager_name)) then return resolve_dep(ps, ms, os, ver, data[manager_name]) end
    end
  end

  return []
end


class Indexer < Jekyll::Generator
  def initialize(config = {})
    super(config)

    # lunr search config
    lunr_config = {
      'excludes' => [],
      'strip_index_html' => false,
      'min_length' => 3,
      'stopwords' => '_stopwords/stop-words-english1.txt'
    }.merge!(config['lunr_search'] || {})
    # lunr excluded files
    @excludes = lunr_config['excludes']
    # if web host supports index.html as default doc, then optionally exclude it from the url
    @strip_index_html = lunr_config['strip_index_html']
    # stop word exclusion configuration
    @min_length = lunr_config['min_length']
    @stopwords_file = lunr_config['stopwords']
    if File.exists?(@stopwords_file)
      @stopwords = IO.readlines(@stopwords_file, :encoding=>'UTF-8').map { |l| l.strip }
    else
      @stopwords = []
    end
  end

  def update_local(site, repo_instances)

    # add / fetch all the instances
    repo_instances.instances.each do |id, repo|

      begin
        unless (site.config['repo_name_whitelist'].length == 0 or site.config['repo_name_whitelist'].include?(repo.name)) then next end
        unless site.config['repo_id_whitelist'].size == 0 or site.config['repo_id_whitelist'].include?(repo.id)
          next
        end

        puts "Updating repo / instance "+repo.name+" / "+repo.id+" from uri: "+repo.uri

        # open or initialize this repo
        local_path = File.join(@checkout_path, repo_instances.name, id)

        # make sure there's an actual uri
        unless repo.uri
          raise IndexException.new("No URI for repo instance " + id, id)
        end

        if @domain_blacklist.include? URI(repo.uri).hostname
          msg = "Repo instance " + id + " has a blacklisted hostname: " + repo.uri.to_s
          puts ('WARNING:' + msg).yellow
          repo.errors << msg
          next
        end

        (1..3).each do |attempt|
          begin
            # open or create a repo
            vcs = get_vcs(repo)
            unless (not vcs.nil? and vcs.valid?) then next end

            # fetch the repo
            begin
              vcs.fetch()
            rescue VCSException => e
              msg = "Could not update repo, using old version: "+e.msg
              puts ("WARNING: "+msg).yellow
              repo.errors << msg
              vcs.close()
            end
            # too many open files if we don't do this
            vcs.close()

            break
          rescue VCSException => e
            puts ("Failed to communicate with source repo after #{attempt} attempt(s)").yellow
            if attempt == 3
              raise IndexException.new("Could not fetch source repo: "+e.msg, id)
            end
          end
        end

      rescue IndexException => e
        @errors[repo_instances.name] << e
        repo.accessible = false
        repo.errors << e.msg
      end

    end
  end

  def extract_package(site, distro, repo, snapshot, checkout_path, path, pkg_type, manifest_xml)

    data = snapshot.data

    begin
      # switch basic info based on build type
      if pkg_type == 'catkin'
        # read the package manifest
        manifest_doc = REXML::Document.new(manifest_xml)
        package_name = REXML::XPath.first(manifest_doc, "/package/name/text()").to_s.strip
        version = REXML::XPath.first(manifest_doc, "/package/version/text()").to_s.strip

        # get dependencies
        deps = REXML::XPath.each(manifest_doc, "/package/build_depend/text() | /package/run_depend/text() | package/depend/text()").map { |a| a.to_s.strip }.uniq

        # determine which deps are packages or system deps
        pkg_deps = {}
        system_deps = {}

        deps.each do |dep_name|
          if @rosdeps.key?(dep_name)
            system_deps[dep_name] = nil
          else
            pkg_deps[dep_name] = nil
          end
        end

      elsif pkg_type == 'rosbuild'
        # check for a stack.xml file
        stack_xml_path = File.join(path,'stack.xml')
        if File.exist?(stack_xml_path)
          stack_xml = IO.read(stack_xml_path)
          stack_doc = REXML::Document.new(stack_xml)
          package_name = REXML::XPath.first(stack_doc, "/stack/name/text()").to_s.strip
          if package_name.length == 0
            package_name = File.basename(File.join(path)).strip
          end
          version = REXML::XPath.first(stack_doc, "/stack/version/text()").to_s.strip
        else
          package_name = File.basename(File.join(path)).strip
          version = "UNKNOWN"
        end

        # read the package manifest
        manifest_doc = REXML::Document.new(manifest_xml)

        # get dependencies
        pkg_deps = Hash[*REXML::XPath.each(manifest_doc, "/package/depend/@package").map { |a| a.to_s.strip }.uniq.collect {|d| [d, nil]}.flatten]
        system_deps = Hash[*REXML::XPath.each(manifest_doc, "/package/rosdep/@name").map { |a| a.to_s.strip }.uniq.collect {|d| [d, nil]}.flatten]
      else
        return nil
      end

      dputs " ---- Found #{pkg_type} package \"#{package_name}\" in path #{path}"

      # extract manifest metadata (same for manifest.xml and package.xml)
      license = REXML::XPath.first(manifest_doc, "/package/license/text()").to_s
      description = REXML::XPath.first(manifest_doc, "/package/description/text()").to_s
      maintainers = REXML::XPath.each(manifest_doc, "/package/maintainer/text()").map { |m| m.to_s.sub('@', ' <AT> ') }
      authors = REXML::XPath.each(manifest_doc, "/package/author/text()").map { |a| a.to_s.sub('@', ' <AT> ') }
      urls = REXML::XPath.each(manifest_doc, "/package/url").map { |elem|
        {
          'uri' => elem.text.to_s,
          'type' => (elem.attributes['type'] or 'Website').to_s,
        }
      }

      # extract other standard exports
      deprecated = REXML::XPath.first(manifest_doc, "/package/export/deprecated/text()").to_s

      # extract rosindex exports
      tags = REXML::XPath.each(manifest_doc, "/package/export/rosindex/tags/tag/text()").map { |t| t.to_s }
      nodes = REXML::XPath.each(manifest_doc, "/package/export/rosindex/nodes").map { |nodes|
        case nodes.attributes["format"]
        when "hdf"
          get_hdf(nodes.text)
        else
          REXML::XPath.each(manifest_doc, "/package/export/rosindex/nodes/node").map { |node|
            {
              'name' => REXML::XPath.first(node,'/name/text()').to_s,
              'description' => REXML::XPath.first(node,'/description/text()').to_s,
              'ros_api' => get_ros_api(REXML::XPath.first(node,'/description/api'))
            }
          }
        end
      }

      # compute the relative path from the root of the repo to this directory
      relpath = Pathname.new(File.join(*path)).relative_path_from(Pathname.new(checkout_path))
      local_package_path = Pathname.new(path)

      # extract package manifest info
      raw_uri = File.join(data['raw_uri'], relpath)
      browse_uri = File.join(data['browse_uri'], relpath)

      # check for readme in same directory as package.xml
      readme_rendered, readme = get_readme(site, path, raw_uri)
      changelog_rendered, changelog = get_changelog(site, path, raw_uri)

      # TODO: don't do this for cmake-based packages
      # look for launchfiles in this package
      launch_files = Dir[File.join(path,'**','*.launch')]
      launch_files += Dir[File.join(path,'**','*.xml')].reject do |f|
        begin
          REXML::Document.new(IO.read(f)).root.name != 'launch'
        rescue Exception => e
          true
        end
      end
      # look for message files in this package
      msg_files = Dir[File.join(path,'**','*.msg')]
      # look for service files in this package
      srv_files = Dir[File.join(path,'**','*.srv')]
      # look for plugin descriptions in this package
      plugin_data = REXML::XPath.each(manifest_doc, '//export/*[@plugin]').map {|e| {'name'=>e.name, 'file'=>e.attributes['plugin'].sub('${prefix}','')}}


      launch_data = []
      launch_data = launch_files.map do |f|
        relative_path = Pathname.new(f).relative_path_from(local_package_path).to_s
        begin
          parse_launch_file(f, relative_path)
        rescue Exception => e
          @errors[repo.name] << IndexException.new("Failed to parse launchfile #{relative_path}: " + e.to_s)
        end
      end

      package_info = {
        'name' => package_name,
        'pkg_type' => pkg_type,
        'distro' => distro,
        'raw_uri' => raw_uri,
        'browse_uri' => browse_uri,
        # required package info
        'version' => version,
        'license' => license,
        'description' => description,
        'maintainers' => maintainers,
        # optional package info
        'authors' => authors,
        'urls' => urls,
        # dependencies
        'pkg_deps' => pkg_deps,
        'system_deps' => system_deps,
        'dependants' => {},
        # exports
        'deprecated' => deprecated,
        # rosindex metadata
        'tags' => tags,
        'nodes' => nodes,
        # readme
        'readme' => readme,
        'readme_rendered' => readme_rendered,
        # changelog
        'changelog' => changelog,
        'changelog_rendered' => changelog_rendered,
        # assets
        'launch_data' => launch_data,
        'plugin_data' => plugin_data,
        'msg_files' => msg_files.map {|f| Pathname.new(f).relative_path_from(local_package_path).to_s },
        'srv_files' => srv_files.map {|f| Pathname.new(f).relative_path_from(local_package_path).to_s },
        'wiki' => {'exists'=>false}
      }

    rescue REXML::ParseException => e
      @errors[repo.name] << IndexException.new("Failed to parse package manifest: " + e.to_s)
      return nil
    end

    return package_info
  end

  def find_packages(site, distro, repo, snapshot, local_path)

    data = snapshot.data
    packages = {}

    # find packages in this branch
    Find.find(local_path) do |path|
      if FileTest.directory?(path)
        # skip certain paths
        if (File.basename(path)[0] == ?.) or File.exist?(File.join(path,'CATKIN_IGNORE')) or File.exist?(File.join(path,'.rosindex_ignore'))
          Find.prune
        end

        # check for package.xml in this directory
        package_xml_path = File.join(path,'package.xml')
        manifest_xml_path = File.join(path,'manifest.xml')
        stack_xml_path = File.join(path,'stack.xml')

        if File.exist?(package_xml_path)
          manifest_xml = IO.read(package_xml_path)
          pkg_type = 'catkin'
        elsif File.exist?(manifest_xml_path)
          manifest_xml = IO.read(manifest_xml_path)
          pkg_type = 'rosbuild'
        else
          next
        end

        # Try to extract a package from this path
        package_info = extract_package(site, distro, repo, snapshot, local_path, path, pkg_type, manifest_xml)

        unless package_info.nil?
          packages[package_info['name']] = package_info
          dputs " -- added package " << package_info['name']

          # stop searching a directory after finding a package
          Find.prune
        end
      end
    end

    return packages
  end

  # scrape a version of a repository for packages and their contents
  def scrape_version(site, repo, distro, snapshot, vcs)

    unless repo.uri
      puts ("WARNING: no URI for "+repo.name+" "+repo.id+" "+distro).yellow
      return
    end

    # initialize this snapshot data
    data = snapshot.data = {
      # get the uri for resolving raw links (for imgages, etc)
      'raw_uri' => get_raw_uri(repo.uri, repo.type, snapshot.version),
      'browse_uri' => get_browse_uri(repo.uri, repo.type, snapshot.version),
      # get the date of the last modification
      'last_commit_time' => vcs.get_last_commit_time(),
      'readme' => nil,
      'readme_rendered' => nil}

    # load the repo readme for this branch if it exists
    data['readme_rendered'], data['readme'] = get_readme(
      site,
      vcs.local_path,
      data['raw_uri'])

    unless repo.release_manifests[distro].nil?
      package_info = extract_package(site, distro, repo, snapshot, vcs.local_path, vcs.local_path, 'catkin', repo.release_manifests[distro])
      packages = {package_info['name'] => package_info}
    else
      packages = find_packages(site, distro, repo, snapshot, vcs.local_path)
    end

    # get all packages from the repo
    # TODO: check if the repo has a release manifest for this distro, and in
    # that case, use that file for package info
    # TODO: split `find_packages` out into two functions:
    #   find_packages (get a list of all package paths in this repo)
    #   scrape_package (extract info from this package) (maybe just move this into the loop below)

    # add the discovered packages to the index
    packages.each do |package_name, package_data|
      # create a new package snapshot
      package = PackageSnapshot.new(package_name, repo, snapshot, package_data)

      # store this package in the repo snapshot
      snapshot.packages[package_name] = package

      # collect tags from discovered packages
      repo.tags = Set.new(repo.tags).merge(package_data['tags']).to_a

      # collect wiki data
      package.data['wiki'] = @wiki_data[package_name]

      # add this package to the global package dict
      @package_names[package_name].instances[repo.id] = repo
      @package_names[package_name].tags = Set.new(@package_names[package_name].tags).merge(package_data['tags']).to_a

      # add this package as the default for this distro
      if @repo_names[repo.name].default
        dputs " --- Setting repo instance " << repo.id << "as default for package " << package_name << " in distro " << distro
        @package_names[package_name].repos[distro] = repo
        @package_names[package_name].snapshots[distro] =  package
      end
    end
  end

  def scrape_repo(site, repo)

    if @domain_blacklist.include? URI(repo.uri).hostname
      msg = "Repo instance " + repo.id + " has a blacklisted hostname: " + repo.uri.to_s
      puts ('WARNING:' + msg).yellow
      repo.errors << msg
      return
    end

    # open or initialize this repo
    begin
      vcs = get_vcs(repo)
    rescue VCSException => e
      raise IndexException.new(e.msg, repo.id)
    end
    if (vcs.nil? or not vcs.valid?) then return end

    some_version_found = false

    # get versions suitable for checkout for each distro
    repo.snapshots.each do |distro, snapshot|

      # get explicit version (this is either set or nil)
      explicit_version = snapshot.version

      if explicit_version.nil?
        dputs " -- no explicit version for distro " << distro << " looking for implicit version "
      else
        dputs " -- looking for version " << explicit_version.to_s << " for distro " << distro
      end

      begin
        # get the version
        unless explicit_version.nil?
          dputs (" Looking for explicit version #{explicit_version}").green
        end
        version, snapshot.version = vcs.get_version(distro, explicit_version)

        # scrape the data (packages etc)
        if version
          puts (" --- scraping version for " << repo.name << " instance: " << repo.id << " distro: " << distro).blue

          # check out this branch
          vcs.checkout(version)

          # check for ignore file
          if File.exist?(File.join(vcs.local_path,'.rosindex_ignore'))
            puts (" --- ignoring version for " << repo.name).yellow
            snapshot.version = nil
          else
            some_version_found = true
            scrape_version(site, repo, distro, snapshot, vcs)
          end
        else
          puts (" --- no version for " << repo.name << " instance: " << repo.id << " distro: " << distro).yellow
        end
      rescue VCSException => e
        @errors[repo.name] << IndexException.new("Could not find version for distro #{distro}: "+e.msg, repo.id)
        repo.errors << e.msg
      end
    end

    if not some_version_found
      msg = "Could not find any valid version."
      @errors[repo.name] << IndexException.new(msg, repo.id)
      repo.errors << (repo.id+': '+msg)
    end

  end

  class SystemDep < Liquid::Drop
    # This represents a system dependency ("rosdep")
    attr_accessor :name, :repo, :snapshot, :version, :data
    def initialize(name, repo, snapshot, data)
      @name = name

      # TODO: get rid of these back-pointers
      @repo = repo
      @snapshot = snapshot
      @version = snapshot.version

      # additionally-collected data
      @data = data
    end
  end

  def load_rosdeps(rosdistro_path, platforms, package_manager_names)
    # this returns 
    # see here for parsing this thing: http://www.ros.org/reps/rep-0111.html

    rosdep_data = Hash.new

    manager_set = Set.new(package_manager_names)

    Dir.glob(File.join(rosdistro_path,'rosdep','*.yaml')) do |rosdep_filename|
      rosdep_yaml = YAML.load_file(rosdep_filename)
      rosdep_data = rosdep_data.deep_merge(rosdep_yaml)
    end

    # update the platforms list
    new_platforms = {}

    # look for new platforms and versions
    rosdep_data.each do |name, deps|
      # iterate over platform names
      deps.each do |platform_name, platform_deps|

        if package_manager_names.include? platform_name then next end
        unless new_platforms.key?(platform_name) then new_platforms[platform_name] = {'versions'=>[]} end
        unless platform_deps.is_a?(Hash) then next end
        if platform_deps.key?('packages') then next end
        if platform_deps.key?('source') then next end
        if manager_set.intersection(platform_deps.keys).length > 0 then next end

        # iterate over version names
        platform_deps.each do |version_or_manager_name, version_deps|
          # add this version name
          new_platforms[platform_name]['versions'] |= [version_or_manager_name]
        end
      end
    end

    dputs "New Platforms: "
    dputs YAML.dump(new_platforms)

    return rosdep_data
  end

  def generate_sorted_paginated(site, elements_sorted, default_sort_key, n_elements, elements_per_page, page_class)

    n_pages = (n_elements / elements_per_page).floor + 1

    (1..n_pages).each do |page_index|

      p_start = (page_index-1) * elements_per_page
      p_end = [n_elements, p_start+elements_per_page].min

      elements_sorted.each do |sort_key, elements|
        # Get a subset of the elements
        elements_sliced = elements.slice(p_start, elements_per_page)

        site.pages << page_class.new( site, sort_key, n_pages, page_index, elements_sliced)
        # create page 1 without a page number or key in the url
        if sort_key == default_sort_key and page_index == 1
          site.pages << page_class.new( site, sort_key, n_pages, page_index, elements_sliced, true)
        end
      end
    end
  end


  def sort_repos(site)
    repos_sorted = {}
    repos_sorted['name']= @repo_names.sort_by { |name, instances| name }

    repos_sorted['time'] = repos_sorted['name'].reverse.sort_by { |name, instances|
      instances.default.snapshots.reject { |d,s|
        not $recent_distros.include?(d)
      }.map { |d,s|
        s.data['last_commit_time'].to_s
      }.max
    }.reverse

    repos_sorted['doc'] = repos_sorted['name'].reverse.sort_by { |name, instances|
      -(instances.default.snapshots.count { |d,s|
        $recent_distros.include?(d) and not s.data['readme_rendered'].nil?
      })
    }

    repos_sorted['released'] = repos_sorted['name'].reverse.sort_by { |name, instances|
      -(instances.default.snapshots.count {|d,s|
        $recent_distros.include?(d) and s.released
      })
    }

    return repos_sorted
  end

  def sort_packages(site)
    packages_sorted = {}

    packages_sorted['name'] = @package_names.sort_by { |name, instances| name }

    packages_sorted['time'] = packages_sorted['name'].reverse.sort_by { |name, instances|
      instances.snapshots.reject { |d,s|
        s.nil? or not $recent_distros.include?(d)
      }.map { |d,s|
        s.snapshot.data['last_commit_time'].to_s
      }.max.to_s
    }.reverse

    packages_sorted['doc'] = packages_sorted['name'].reverse.sort_by { |name, instances|
      -(instances.snapshots.count { |d,s|
        not s.nil? and $recent_distros.include?(d) and not s.data['readme_rendered'].nil?
      })
    }

    packages_sorted['released'] = packages_sorted['name'].reverse.sort_by { |name, instances|
      -(instances.snapshots.count { |d,s|
        not s.nil? and $recent_distros.include?(d) and s.snapshot.released
      })
    }

    return packages_sorted
  end

  def sort_rosdeps(site)
    rosdeps_sorted = {}

    rosdeps_sorted['name'] = @rosdeps.sort_by { |name, details| name }

    return rosdeps_sorted
  end

  def write_release_manifests(site, repo, package_name, default)
    $all_distros.each do |distro|
      unless repo.release_manifests[distro].nil?
        manifest_path = File.join('p', package_name, unless default then repo.id else '' end, distro)
        dest_manifest_path = File.join(site.dest,manifest_path)

        unless File.exists?(dest_manifest_path) or File.directory?(dest_manifest_path) then FileUtils.mkdir_p(dest_manifest_path) end

        IO.write(File.join(dest_manifest_path,'package.xml'), repo.release_manifests[distro])
        site.static_files << PackageManifestFile.new(site, site.dest, '/'+manifest_path, 'package.xml')
      end
    end
  end

  def strip_stopwords(text)
    begin
      text = text.encode('UTF-16', :undef => :replace, :invalid => :replace, :replace => "??").encode('UTF-8').split.delete_if() do |x|
        t = x.downcase.gsub(/[^a-z']/, '')
        t.length < @min_length || @stopwords.include?(t)
      end.join(' ')
    rescue ArgumentError
      puts text.encode('UTF-16', :undef => :replace, :invalid => :replace, :replace => "??").encode('UTF-8')
      throw
    end
  end

  def generate(site)

    # create the checkout path if necessary
    @checkout_path = File.expand_path(site.config['checkout_path'])
    puts ("Using checkout path: " + @checkout_path).green
    unless File.exist?(@checkout_path)
      FileUtils.mkpath(@checkout_path)
    end

    # construct list of known ros distros
    $recent_distros = site.config['distros']
    $all_distros = site.config['distros'] + site.config['old_distros']

    @domain_blacklist = site.config['domain_blacklist']

    @db_cache_filename = if site.config['db_cache_filename'] then File.join(site.source,site.config['db_cache_filename']) else 'rosindex.db' end
    @use_db_cache = (site.config['use_db_cache'] and File.exist?(@db_cache_filename))

    @skip_discover = site.config['skip_discover']
    @skip_update = site.config['skip_update']
    @skip_scrape = site.config['skip_scrape']

    if @use_db_cache
      puts ("Reading cache: " << @db_cache_filename).blue
      @db = Marshal.load(IO.read(@db_cache_filename))
    else
      @db = RosIndexDB.new
    end

    # rosdeps
    @rosdeps = @db.rosdeps
    # the global index of repos
    @all_repos = @db.all_repos
    # the list of repo instances by name
    @repo_names = @db.repo_names
    # the list of package instances by name
    @package_names = @db.package_names
    # the list of errors encountered
    @errors = @db.errors

    # a dict of data scraped from the wiki
    # currently the only information is the title-index on the wiki
    @wiki_data = {}

    # load rosdep data
    # TODO: check deps against this when generating pages
    raw_rosdeps = load_rosdeps(
      site.config['rosdistro_path'],
      site.config['platforms'],
      site.config['package_manager_names'].keys)

    raw_rosdeps.each do |dep_name, dep_data|
      platforms = site.config['platforms']
      manager_set = Set.new(site.config['package_manager_names'])

      full_dep_data = {}
      platforms.each do |platform_key, platform_details|
        if platform_details['versions'].size > 0
          full_dep_data[platform_key] = {}
          platform_details['versions'].each do |version_key, version_name|
            full_dep_data[platform_key][version_key] = resolve_dep(platforms, manager_set, platform_key, version_key, dep_data)
          end
        else
          full_dep_data[platform_key] = resolve_dep(platforms, manager_set, platform_key, 'any_version', dep_data)
        end
      end

      @rosdeps[dep_name] = full_dep_data
    end

    # get the repositories from the rosdistro files, rosdoc rosinstall files, and other sources
    unless @skip_discover

      # read in rosdistro sources
      $all_distros.reverse_each do |distro|

        puts "processing rosdistro: "+distro

        # read in the rosdistro distribution file
        rosdistro_filename = File.join(site.config['rosdistro_path'],distro,'distribution.yaml')
        if File.exist?(rosdistro_filename)
          distro_data = YAML.load_file(rosdistro_filename)
          distro_data['repositories'].each do |repo_name, repo_data|

            unless (site.config['repo_name_whitelist'].length == 0 or site.config['repo_name_whitelist'].include?(repo_name)) then next end

            begin
              # limit repos if requested
              if not @repo_names.has_key?(repo_name) and site.config['max_repos'] > 0 and @repo_names.length > site.config['max_repos'] then next end

              dputs " - "+repo_name

              source_uri = nil
              source_version = nil
              source_type = nil
              release_manifest_xml = nil
              release_version = nil

              # only index if it has a source repo
              if repo_data.has_key?('source')
                source_uri = repo_data['source']['url'].to_s
                source_type = repo_data['source']['type'].to_s
                source_version = repo_data['source']['version'].to_s
                source_version = (if repo_data['source'].key?('version') and repo_data['source']['version'] != 'HEAD' then repo_data['source']['version'].to_s else 'REMOTE_HEAD' end)
              elsif repo_data.has_key?('doc')
                source_uri = repo_data['doc']['url'].to_s
                source_type = repo_data['doc']['type'].to_s
                source_version = (if repo_data['doc'].key?('version') and repo_data['doc']['version'] != 'HEAD' then repo_data['doc']['version'].to_s else 'REMOTE_HEAD' end)
              elsif repo_data.has_key?('release')
                # NOTE: also, sometimes people use the release repo as the "doc" repo

                # get the release repo to get the upstream repo
                release_uri = cleanup_uri(repo_data['release']['url'].to_s)
                release_repo_path = File.join(@checkout_path,'_release_repos',repo_name,get_id(release_uri))

                tracks_file = nil

                (1..3).each do |attempt|
                  begin
                    # clone the release repo
                    release_vcs = GIT.new(release_repo_path, release_uri)

                    begin
                      release_vcs.fetch()
                    rescue VCSException => e

                    end

                    # get the tracks file
                    ['master','bloom'].each do |branch_name|
                      branch, _ = release_vcs.get_version(branch_name)

                      if branch.nil? then next end

                      release_vcs.checkout(branch)

                      begin
                        # get the tracks file
                        tracks_file = YAML.load_file(File.join(release_repo_path,'tracks.yaml'))
                        # get package manifest files (if any)
                        release_manifest_path = Dir[File.join(release_repo_path,distro,'package.xml')].first
                        unless release_manifest_path.nil?
                          release_manifest_xml = IO.read(release_manifest_path)
                        end

                        unless tracks_file.nil? then break end
                      rescue
                        next
                      end
                    end

                    # too many open files if we don't do this
                    release_vcs.close()

                    break
                  rescue VCSException => e
                    puts ("Failed to communicate with release repo after #{attempt} attempt(s)").yellow
                    if attempt == 3
                      raise IndexException.new("Could not fetch release repo for repo: "+repo_name+": "+e.msg)
                    end
                  end
                end

                if tracks_file.nil?
                  raise IndexException.new("Could not find tracks.yaml file in release repo: " + repo_name + " in rosidstro file: " + rosdistro_filename)
                end

                tracks_file['tracks'].each do |track_name, track|
                  if track['ros_distro'] == distro
                    source_uri = track['vcs_uri']
                    source_type = track['vcs_type']
                    # prefer devel branch if available
                    if not track['devel_branch'].nil?
                      source_version = track['devel_branch'].strip
                    elsif not track['release_tag'].nil? and not track['last_version'].nil?
                      source_version = track['release_tag'].to_s.strip
                      # NOTE: when ruby loads yaml, it turns "foo: :{bar}" into {'foo'=>:"bar"} and "foo: v:{bar}" into {'foo'=>'v:{bar}'}
                      source_version.gsub!(':{version}',track['last_version'].to_s)
                      source_version.gsub!('{version}',track['last_version'].to_s)
                    elsif not track['last_version'].nil?
                      source_version = track['last_version'].to_s
                    end
                    release_version = track['last_version'].to_s.strip
                    unless source_uri.nil? or source_type.nil? or source_version.nil?
                      break
                    end
                  end
                end

                if source_uri.nil? or source_type.nil? or source_version.nil?
                  raise IndexException.new("Could not determine source repo from release repo: " + repo_name + " in rosidstro file: " + rosdistro_filename)
                end
              else
                raise IndexException.new("No source, doc, or release information for repo: " + repo_name+ " in rosidstro file: " + rosdistro_filename)
              end

              # create a new repo structure for this remote
              begin
                repo = Repo.new(
                  repo_name,
                  source_type,
                  source_uri,
                  'Via rosdistro: '+distro,
                  @checkout_path)
              rescue
                raise IndexException.new("Failed to create repo from #{source_type} repo #{source_uri}: " + repo_name+ " in rosidstro file: " + rosdistro_filename)
              end

              if @all_repos.key?(repo.id)
                repo = @all_repos[repo.id]
              else
                puts " -- Adding repo " << repo.name << " instance: " << repo.id << " from uri: " << repo.uri.to_s << " with version: " <<source_version
                # store this repo in the unique index
                @all_repos[repo.id] = repo
              end

              # get maintainer status
              if repo_data.key?('status')
                repo.status = repo_data['status']
              end

              # add the specific version from this instance
              repo.snapshots[distro] = RepoSnapshot.new(source_version, distro, repo_data.key?('release'), true)

              # add the release manifest, if found
              unless release_manifest_xml.nil?
                release_manifest_xml.gsub!(':{version}',(release_version or '0.0.0'))
              end
              repo.release_manifests[distro] = release_manifest_xml

              # store this repo in the name index
              @repo_names[repo.name].instances[repo.id] = repo
              @repo_names[repo.name].default = repo
            rescue IndexException => e
              @errors[repo_name] << e
            end
          end
        end

        # read in the old documentation index file (if it exists)
        doc_path = File.join(site.config['rosdistro_path'],'doc',distro)

        puts "Examining doc path: " << doc_path

        Dir.glob(File.join(doc_path,'*.rosinstall').to_s) do |rosinstall_filename|

          puts 'Indexing rosinstall repo data file: ' << rosinstall_filename

          rosinstall_data = YAML.load_file(rosinstall_filename)
          rosinstall_data.each do |rosinstall_entry|
            rosinstall_entry.each do |repo_type, repo_data|

              begin
                if repo_data.nil? then next end
                #puts repo_type.inspect
                #puts repo_data.inspect

                # extract the garbage
                repo_name = repo_data['local-name'].to_s.split(File::SEPARATOR)[-1]
                repo_uri = repo_data['uri'].to_s
                repo_version = (if repo_data.key?('version') and repo_data['version'] != 'HEAD' then repo_data['version'].to_s else 'REMOTE_HEAD' end)

                # limit number of repos indexed if in devel mode
                if not @repo_names.has_key?(repo_name) and site.config['max_repos'] > 0 and @repo_names.length > site.config['max_repos'] then next end
                unless (site.config['repo_name_whitelist'].length == 0 or site.config['repo_name_whitelist'].include?(repo_name)) then next end

                puts " - #{repo_name}"

                if repo_type == 'bzr'
                  raise IndexException.new("ERROR: some fools trying to use bazaar: " + rosinstall_filename)
                end

                # create a new repo structure for this remote
                repo = Repo.new(
                  repo_name,
                  repo_type,
                  repo_uri,
                  'Via rosdistro doc: '+distro,
                  @checkout_path)

                if @all_repos.key?(repo.id)
                  repo = @all_repos[repo.id]
                else
                  puts " -- Adding repo for " << repo.name << " instance: " << repo.id << " from uri: " << repo.uri.to_s
                  # store this repo in the unique index
                  @all_repos[repo.id] = repo
                end

                # add the specific version from this instance
                repo.snapshots[distro] = RepoSnapshot.new(repo_version, distro, false, true)

                # store this repo in the name index
                @repo_names[repo.name].instances[repo.id] = repo
                @repo_names[repo.name].default = repo
              rescue IndexException => e
                @errors[repo_name] << e
              end
            end
          end
        end
      end

      # add additional repo instances to the main dict
      Dir.glob(File.join(site.config['repos_path'],'*.yaml')) do |repo_filename|

        # limit repos if requested
        #if site.config['max_repos'] > 0 and @all_repos.length > site.config['max_repos'] then break end

        # read in the repo data
        repo_name = File.basename(repo_filename, File.extname(repo_filename)).to_s
        repo_data = YAML.load_file(repo_filename)

        puts " - Adding repositories for " << repo_name

        # add all the instances
        repo_data['instances'].each do |instance|

          # create a new repo structure for this remote
          repo = Repo.new(
            repo_name,
            instance['type'],
            instance['uri'],
            instance['purpose'],
            @checkout_path)

          uri = repo.uri

          dputs " -- Added repo for " << repo.name << " instance: " << repo.id << " from uri " << repo.uri.to_s

          # add distro versions for instance
          $all_distros.each do |distro|

            # get the explicit version identifier for this distro
            explicit_version = if instance.key?('distros') and instance['distros'].key?(distro) and instance['distros'][distro].key?('version') then instance['distros'][distro]['version'] else nil end

            # add the specific version from this instance
            repo.snapshots[distro].version = explicit_version
            repo.snapshots[distro].released = false
          end

          # store this repo in the unique index
          @all_repos[repo.id] = repo

          # store this repo in the name index
          @repo_names[repo.name].instances[repo.id] = repo
          if instance['default'] or @repo_names[repo.name].default.nil?
            @repo_names[repo.name].default = repo
          end
        end
      end

      # add attic repos
      attic_filename = site.config['attic_file']
      attic_data = {}
      # read in the repo data
      if File.exists?(attic_filename)
        attic_data = YAML.load_file(attic_filename)
      end

      attic_data.each do |repo_name, instances|
        puts " - Adding repositories for " << repo_name

        # add all the instances
        instances.each do |id, instance|

          # create a new repo structure for this remote
          repo = Repo.new(
            repo_name,
            instance['type'],
            instance['uri'],
            'attic mirror',
            @checkout_path)

          repo.attic = true

          uri = repo.uri

          dputs " -- Added attic repo for " << repo.name << " instance: " << repo.id << " from uri " << repo.uri.to_s

          # add distro versions for instance
          $all_distros.each do |distro|

            # get the explicit version identifier for this distro
            explicit_version = if instance.fetch('distros',{})[distro] then instance['distros'][distro] else nil end

            # add the specific version from this instance
            repo.snapshots[distro].version = explicit_version
            repo.snapshots[distro].released = false
          end

          # store this repo in the unique index
          # note this will overwrite the mirrored repo
          @all_repos[repo.id] = repo

          # store this repo in the name index
          @repo_names[repo.name].instances[repo.id] = repo
          if instance['default'] or @repo_names[repo.name].default.nil?
            @repo_names[repo.name].default = repo
          end
        end
      end

      puts "Found " << @all_repos.length.to_s << " repositories corresponding to " << @repo_names.length.to_s << " repo identifiers."
    end

    # clone / fetch all the repos
    unless @skip_update
      work_q = Queue.new
      @repo_names.sort.map.each {|r| work_q.push r}
      puts "Fetching sources with " << site.config['checkout_threads'].to_s << " threads."
      workers = (0...site.config['checkout_threads']).map do
        Thread.new do
          begin
            while ri = work_q.pop(true)
              update_local(site, ri[1])
            end
          rescue ThreadError
          end
        end
      end; "ok"
      workers.map(&:join); "ok"
    end

    # Load wiki title index
    @wiki_data = parse_wiki_title_index(site.config['wiki_title_index_filename'])

    # scrape all the repos
    unless @skip_scrape
      n_scraped = 0
      n_total = @all_repos.length
      puts "Scraping #{n_total} known repos..."
      @all_repos.to_a.sort_by{|repo_id, repo| repo.name}.each do |repo_id, repo|
        unless (site.config['repo_name_whitelist'].length == 0 or site.config['repo_name_whitelist'].include?(repo.name)) then next end
        if site.config['repo_id_whitelist'].size == 0 or site.config['repo_id_whitelist'].include?(repo.id)

          puts "[%05.2f%%] Scraping #{repo.id}..." % (n_scraped/n_total.to_f*100.0)
          begin
            scrape_repo(site, repo)
          rescue IndexException => e
            @errors[repo.name] << e
            repo.errors << e.msg
          end
          n_scraped = n_scraped + 1
        end
      end
    end


    if site.config['use_db_cache']
      # backup the current db if it exists
      if File.exist?(@db_cache_filename) then FileUtils.mv(@db_cache_filename, @db_cache_filename+'.bak') end
      # save scraped data into the cache db
      File.open(@db_cache_filename, 'w') {|f| f.write(Marshal.dump(@db)) }
    end


    puts "Generating update report...".blue

    # read the old report
    old_report = YAML.load(IO.read(site.config['report_filename']))

    # write out the report and the diff
    new_report = @db.get_report
    report_yaml = new_report.to_yaml
    report_filename = 'index_report.yaml'

    if not File.directory?(site.dest)
      Dir.mkdir(site.dest)
    end

    File.open(File.join(site.dest, report_filename),'w+') {|f| f.write(report_yaml) }
    site.static_files << ReportFile.new(site, site.dest, "/", report_filename)
    File.open(site.config['report_filename'],'w') {|f| f.write(report_yaml) }

    report_diff = @db.diff_report(old_report, new_report)
    report_yaml = report_diff.to_yaml
    report_filename = 'index_report_diff.yaml'
    File.open(File.join(site.dest, report_filename),'w') {|f| f.write(report_yaml) }
    site.static_files << ReportFile.new(site, site.dest, "/", report_filename)
    File.open(site.config['report_diff_filename'],'w') {|f| f.write(report_yaml) }

    # compute post-scrape details
    # TODO: check for missing deps or just leave them as nil?
    @repo_names.each do |repo_name, repo_instances|
      repo_instances.instances.each do |instance_id, repo|
        repo.snapshots.each do |distro, snapshot|
          snapshot.packages.each do |package_name, package_snapshot|
            # add package details
            package_snapshot.data['pkg_deps'].keys.each do |dep_name|
              if @package_names.key?(dep_name)
                # add forward dep
                # forward deps should point to the package instances page,
                # since it might be any given instance
                package_snapshot.data['pkg_deps'][dep_name] = @package_names[dep_name]
              end

              # add reverse dep to each dep
              # reverse deps can point to the exact instance which depends on this package
              # these are keyed by package name => list of instances
              @package_names[dep_name].instances.each do |dep_instance_id, dep_repo|
                if dep_repo.snapshots[distro].packages.key?(dep_name)
                  dependants = dep_repo.snapshots[distro].packages[dep_name].data['dependants']
                  unless dependants.key?(package_name) then dependants[package_name] = [] end
                  dependants[package_name] << {
                    'repo' => repo,
                    'id' => instance_id,
                    'package' => package_snapshot
                  }
                end
              end
            end
            # add rosdep details
            package_snapshot.data['system_deps'].keys.each do |dep_name|
              if @rosdeps.key?(dep_name)
                package_snapshot.data['system_deps'][dep_name] = @rosdeps[dep_name]
              end
            end
          end
        end
      end
    end

    # generate pages for all repos
    @repo_names.each do |repo_name, repo_instances|

      # create the repo pages
      dputs " - creating pages for repo "+repo_name+"..."

      # create a list of instances for this repo
      site.pages << RepoInstancesPage.new(site, repo_instances)

      # create the page for the default instance
      site.pages << RepoPage.new(site, repo_instances, repo_instances.default, true)

      # create pages for each repo instance
      repo_instances.instances.each do |instance_id, instance|
        site.pages << RepoPage.new(site, repo_instances, instance, false)
      end
    end

    # create package pages
    puts ("Found "+String(@package_names.length)+" packages total.").green
    puts ("Generating package pages...").blue

    @package_names.each do |package_name, package_instances|

      dputs "Generating pages for package " << package_name << "..."

      # create default package page
      site.pages << PackagePage.new(site, package_instances)

      # create package page which lists all the instances
      site.pages << PackageInstancesPage.new(site, package_instances)

      # create a page for each package instance
      package_instances.instances.each do |instance_id, instance|
        dputs "Generating page for package " << package_name << " instance " << instance_id << "..."
        site.pages << PackageInstancePage.new(site, package_instances, instance, package_name)

        repo = @all_repos[instance_id]
        write_release_manifests(site, repo, package_name, false)
        if @repo_names[repo.name].default.id == repo.id
          write_release_manifests(site, repo, package_name, true)
        end
      end
    end

    # create repo list pages
    puts ("Generating repo list pages...").blue

    repos_sorted = sort_repos(site)
    generate_sorted_paginated(site, repos_sorted, 'time', @repo_names.length, site.config['repos_per_page'], RepoListPage)

    # create package list pages
    puts ("Generating package list pages...").blue

    packages_sorted = sort_packages(site)
    generate_sorted_paginated(site, packages_sorted, 'time', @package_names.length, site.config['packages_per_page'], PackageListPage)

    # create rosdep list pages
    puts ("Generating rosdep list pages...").blue

    @rosdeps.each do |dep_name, full_dep_data|
      site.pages << DepPage.new(site, dep_name, raw_rosdeps[dep_name], full_dep_data)
    end

    rosdeps_sorted = sort_rosdeps(site)
    generate_sorted_paginated(site, rosdeps_sorted, 'name', @rosdeps.length, site.config['packages_per_page'], DepListPage)


    # create lunr index data
    unless site.config['skip_search_index']
      puts ("Generating search index...").blue

      index = []

      @all_repos.each do |instance_id, repo|
        repo.snapshots.each do |distro, repo_snapshot|

          if repo_snapshot.version == nil then next end

          repo_snapshot.packages.each do |package_name, package|

            if package.nil? then next end

            p = package.data

            readme_filtered = if p['readme'] then self.strip_stopwords(p['readme']) else "" end

            index << {
              'id' => index.length,
              'baseurl' => site.config['baseurl'],
              'url' => File.join('/p',package_name,instance_id)+"#"+distro,
              'last_commit_time' => repo_snapshot.data['last_commit_time'],
              'tags' => (p['tags'] + package_name.split('_')) * " ",
              'name' => package_name,
              'repo_name' => repo.name,
              'released' => if repo_snapshot.released then 'is:released' else '' end,
              'unreleased' => if repo_snapshot.released then 'is:unreleased' else '' end,
              'version' => p['version'],
              'description' => p['description'],
              'maintainers' => p['maintainers'] * " ",
              'authors' => p['authors'] * " ",
              'distro' => distro,
              'instance' => repo.id,
              'readme' => readme_filtered
            }

            dputs 'indexed: ' << "#{package_name} #{instance_id} #{distro}"
          end
        end
      end

      # generate index in the json format needed by lunr
      index_json = JSON.generate({'entries'=>index})

      # save the json file
      # TODO: is there no way to do this in fewer lines?
      Dir::mkdir(site.dest) unless File.directory?(site.dest)
      index_filename = 'search.json'

      File.open(File.join(site.dest, index_filename), "w+") do |index_file|
        index_file.write(index_json)
      end

      # add this file as a static site file
      site.static_files << SearchIndexFile.new(site, site.dest, "/", index_filename)

      # precompute the lunr index
      lunr_cmd = File.join(site.source,'node_modules','lunr-index-build','bin','lunr-index-build')
      lunr_index_fields = [
        '-r','id',
        '-f','baseurl',
        '-f','instance',
        '-f','url',
        '-f','tags:100',
        '-f','name:100',
        '-f','version',
        '-f','description:50',
        '-f','maintainers',
        '-f','authors',
        '-f','distro',
        '-f','readme',
        '-f','released',
        '-f','unreleased'
      ].join(' ')

      puts ("Precompiling lunr index...").blue

      input_file = File.join(site.dest,index_filename)
      output_file = File.join(site.dest,'index.json')
      errput_file = File.join(site.dest,'index_errors')
      full_cmd = "#{lunr_cmd} #{lunr_index_fields}"
      puts ("Full lunr cmd: #{full_cmd} < #{input_file} > #{output_file}")

      pid = spawn(full_cmd,
        :in=>input_file,
        :out=>[output_file,"w"])
      Process.waitpid(pid)

      #if success != true
        #puts ("Could not generate lunr index!").red
      #end

      site.static_files << SearchIndexFile.new(site, site.dest, "/", "index.json")
    end

    # create stats page
    puts "Generating statistics page...".blue
    site.pages << StatsPage.new(site, @package_names, @all_repos, @errors)

    # create errors page
    puts "Generating errors page...".blue
    site.pages << ErrorsPage.new(site, @errors)
  end

end
