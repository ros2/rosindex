require 'addressable'
require 'fileutils'
require 'nokogiri'

require_relative '../_ruby_libs/pages'

class Hash
  def self.recursive
    new { |hash, key| hash[key] = recursive }
  end
end

class DocPageGenerator < Jekyll::Generator
  safe true

  def initialize(config = {})
    super(config)
  end

  def generate(site)
    all_repos = site.data['remotes']['repositories']
    site.config['docs_repos'].each do |repo_name, repo_options|
      next unless all_repos.key? repo_name

      repo_path = Pathname.new(File.join("_remotes", repo_name))
      repo_data_path = File.join(repo_path, 'rosindex.yml')
      repo_data = File.file?(repo_data_path) ? YAML.load_file(repo_data_path) : {}
      repo_data.update(all_repos[repo_name])

      repo_pages = {}
      convert_with_sphinx(repo_name, repo_path, repo_data).each do |path, content|
        parent_path, * = path.rpartition('/')
        parent_page = repo_pages.fetch(parent_path, nil)
        if parent_page.nil? and repo_options.key? 'description'
          content['title'] = repo_options['description']
        end
        site.pages << repo_pages[path] = DocPage.new(
          site, parent_page, "#{repo_name}/#{path}", content
        )
      end
    end
  end

  def copy_docs(src_path, dst_path)
    copied_docs = Hash.new
    src_path = Pathname.new(src_path)
    Dir.glob(File.join(src_path, '**/*.rst'),
             File::FNM_CASEFOLD).each do |src_doc_path|
      src_doc_path = Pathname.new(src_doc_path)
      dst_doc_path = Pathname.new(File.join(
        dst_path, src_doc_path.relative_path_from(src_path)
      ))
      unless File.directory? File.dirname(dst_doc_path)
        FileUtils.makedirs(File.dirname(dst_doc_path))
      end
      FileUtils.copy_entry(src_doc_path, dst_doc_path, preserve = true)
      copied_docs[src_doc_path] = dst_doc_path
    end
    copied_docs
  end

  def generate_edit_url(repo_data, original_filepath)
    is_https = repo_data['url'].include? "https"
    is_github = repo_data['url'].include? "github.com"
    is_bitbucket = repo_data['url'].include? "bitbucket.org"
    unless is_github or is_bitbucket
      raise ValueError("Cannot generate edition URL. Unknown organization for repository: #{repo_data['url']}")
    end
    if is_https
      uri = URI(repo_data['url'])
      host = uri.host
      organization, repo = uri.path.split("/").reject { |c| c.empty? }
    else # ssh
      host, path = repo_data['url'].split("@")[1].split(":")
      organization, repo = path.split("/")
    end
    repo.chomp!(".git") if repo.end_with? ".git"
    if is_github
      edit_url = "https://#{host}/#{organization}/#{repo}/edit/#{repo_data['version']}"
      return File.join(edit_url, original_filepath)
    elsif is_bitbucket
      edit_url = "https://#{host}/#{organization}/#{repo}/src/#{repo_data['version']}"
      return File.join(edit_url, original_filepath) +
             "?mode=edit&spa=0&at=#{repo_data['version']}&fileviewer=file-view-default"
    end
  end

  def convert_with_sphinx(repo_name, repo_path, repo_data)
    sphinx_input_path = Pathname.new(File.join('_sphinx', 'repos', repo_name))
    FileUtils.rm_r(sphinx_input_path) if File.directory? sphinx_input_path
    repo_sources_path = Pathname.new(
      File.join(repo_path, repo_data.fetch("sources_dir", "source"))
    )
    copied_docs_paths = copy_docs(repo_sources_path, sphinx_input_path)
    return if copied_docs_paths.empty?
    sphinx_output_path = Pathname.new(File.join('_sphinx', '_build', repo_name))
    FileUtils.rm_r(sphinx_output_path) if File.directory? sphinx_output_path
    FileUtils.makedirs(sphinx_output_path)
    command = "sphinx-build -b json -c #{repo_path} #{sphinx_input_path} #{sphinx_output_path}"
    pid = Kernel.spawn(command)
    Process.wait pid
    repo_content = Hash.recursive
    Dir.glob(File.join(sphinx_output_path, '**/*.fjson'),
             File::FNM_CASEFOLD).each do |json_file|
      json_content = JSON.parse(File.read(json_file))
      rel_path = Pathname(json_file).relative_path_from(sphinx_output_path).sub_ext(".rst")
      src_path = Pathname(File.join(repo_sources_path, rel_path))
      # Check if the fjson has a rst counterpart
      if copied_docs_paths.key?(src_path) then
        json_content["edit_url"] = generate_edit_url(
          repo_data, src_path.relative_path_from(repo_path)
        )
        json_content["indexed_page"] = \
          repo_data.fetch("index_pattern", ["*.rst", "**/*.rst"]).any? do |pattern|
            File.fnmatch?(pattern, src_path.relative_path_from(repo_sources_path))
          end
      end
      permalink = json_content["current_page_name"]
      if File.basename(permalink) == "index"
        permalink = File.dirname(permalink)
        permalink = '' if permalink == '.'
      end
      repo_content[permalink] = json_content
    end
    repo_content.sort {|a, b| a[0].length <=> b[0].length}
  end
end
