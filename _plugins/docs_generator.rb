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
    all_distros = site.config['distros'] + site.config['old_distros']
    site.config['independent_docs'].each do |name, options|
      versioned_content = Hash.recursive
      options['versions'].each do |distro, repo_name|
        next unless all_repos.key? repo_name
        next unless all_distros.include? distro
        repo_data = all_repos[repo_name]
        convert_with_sphinx(repo_name, repo_data).each do |path, content|
          versioned_content[path][distro] = content
        end
      end
      versioned_content.each do |path, content|
        site.pages << DocPage.new(
          site, name, options['description'] || name,
          path, content
        )
      end
    end
  end

  def copy_docs(src_path, dst_path)
    copied_docs = Hash.new
    src_path = Pathname.new(src_path)
    Dir.glob(File.join(src_path, '**/*.{md, rst}'),
             File::FNM_CASEFOLD).each do |src_doc_path|
      src_doc_path = Pathname.new(src_doc_path)
      dst_doc_path = Pathname.new(File.join(
        dst_path, src_doc_path.relative_path_from(src_path)
      ).sub(/readme\.(md|rst)$/i, 'index.\1'))
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

  def convert_with_sphinx(repo_name, repo_data)
    repo_path = Pathname.new(File.join("_remotes", repo_name))
    in_path = Pathname.new(File.join('_sphinx', 'repos', repo_name))
    FileUtils.rm_r(in_path) if File.directory? in_path
    copied_docs_paths = copy_docs(repo_path, in_path)
    return if copied_docs_paths.empty?
    out_path = Pathname.new(File.join('_sphinx', '_build', repo_name))
    FileUtils.rm_r(out_path) if File.directory? out_path
    FileUtils.makedirs(out_path)
    command = "sphinx-build -b json -c _sphinx #{in_path} #{out_path}"
    pid = Kernel.spawn(command)
    Process.wait pid
    repo_content = Hash.recursive
    copied_docs_paths.each do |src_path, dst_path|
      json_path = File.join(
        out_path, dst_path.relative_path_from(in_path)
      ).sub(File.extname(dst_path), '.fjson')
      next unless File.file? json_path
      json_content = JSON.parse(File.read(json_path))
      json_content["edit_url"] = generate_edit_url(
        repo_data, src_path.relative_path_from(repo_path)
      )
      permalink = json_content["current_page_name"]
      if File.basename(permalink) == "index"
        permalink = File.dirname(permalink)
      end
      # Generate HTML tables that were left with markdown syntax by sphinx.
      # Please refer to this issue for more information:
      # https://github.com/rtfd/recommonmark/issues/3
      # Although there's a sphinx-markdown-tables extension now, its
      # functionality is limited and doesn't fit our requirements.
      html_doc = Nokogiri::HTML(json_content["body"])
      html_doc.css('p').each do |paragraph|
        if paragraph.content.strip[0] == "|"
          html_table = Kramdown::Document.new(paragraph.inner_html).to_html
          nokogiri_table = Nokogiri::HTML(html_table)
          next unless nokogiri_table.css('td').length > 0
          nokogiri_table.css('table').each do |table|
            table.set_attribute("class", "table table-striped table-dark")
            # Fixes table by removing the second row that's always filled
            # with hyphens, as a consequence of conversion.
            table.css('tr')[1].remove
          end
          paragraph.replace(nokogiri_table.to_html)
        end
      end
      # Local URLs with fragments are typical of header anchors in Markdown
      # documents. However, (1) recommonmark does not cross link this kind
      # of links and (2) fragment usage clashes with the distro switch
      # mechanism. Mark them as unsupported for now.
      html_doc.css('a').each do |anchor|
        url = Addressable::URI.parse(anchor['href'])
        next unless not url.scheme and url.fragment
        raise "Unsupported link with fragment '#{url.fragment}'" \
              + " found at #{permalink} inside #{repo_name} repo"
      end
      json_content["body"] = html_doc.css('body').first.inner_html
      repo_content[permalink] = json_content
    end
    repo_content
  end
end
