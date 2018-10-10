require 'fileutils'

class DocPage < Jekyll::Page
  def initialize(site, repo_name, page_data)
    basepath = File.join('doc', repo_name)
    @site = site
    @base = site.source
    @name = "index.html"
    if page_data["current_page_name"].scan(/index|readme/i).length > 0
      @dir = "doc/#{repo_name}/"
    else
      @dir = "doc/#{repo_name}/#{page_data["current_page_name"]}/"
    end
    self.process(@name)
    self.data ||= {}
    self.data['layout'] = "doc"
    self.content = page_data["body"]
    self.data['file_extension'] = page_data["page_source_suffix"]
    self.data['title'] = page_data["current_page_name"]
  end
end

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
    doc_repos = site.config['docs_repos']
    docfiles = search_docfiles(doc_repos)
    copy_docs_to_sphinx_location(docfiles)
    docs_data = convert_with_sphinx(docfiles)
    docs_data.each do |repo_name, repo_docs|
      repo_docs.each do |key, doc_data|
        site.pages << DocPage.new(site, repo_name, doc_data)
      end
    end
  end

  def copy_docs_to_sphinx_location(docfiles)
    docfiles.each do |repo_name, files|
      origin_dir = File.join("_remotes", repo_name)
      destination_dir = File.join("_sphinx", "repos", repo_name)
      unless File.directory?(destination_dir)
        FileUtils.makedirs(destination_dir)
      end
      files.each do |file|
        if file.scan(/readme/i).length > 0
          dest_name = "index" + File.extname(file)
        else
          dest_name = File.basename(file)
        end
        FileUtils.copy_entry(file, File.join(destination_dir, dest_name), preserve = true)
      end
    end
  end

  def search_docfiles(doc_repos_hash)
    docfiles_hash = Hash.new
    doc_repos_hash.each do |repo_name, repo|
      docs_in_repo = Array.new
      Dir.glob(File.join("_remotes", repo_name) + '**/*.{md, rst}', File::FNM_CASEFOLD) do |doc_relpath|
        docs_in_repo.push(doc_relpath)
      end
      docfiles_hash[repo_name] = docs_in_repo
    end
    docfiles_hash
  end

  def convert_with_sphinx(docfiles)
    json_files_data = Hash.recursive
    docfiles.each do |repo_name, files|
      command = "sphinx-build -b json -c _sphinx #{File.join('_sphinx', 'repos', repo_name)} _sphinx/_build"
      puts command
      pid = Kernel.spawn(command)
      Process.wait pid
      files.each do |file|
        name = File.basename(file, File.extname(file))
        if name.scan(/readme/i).length > 0
          name = "index"
        end
        json_file = File.join('_sphinx/_build/', name + '.fjson')
        next unless File.file?(json_file)
        json_content = File.read(json_file)
        json_files_data[repo_name][name] = JSON.parse(json_content)
      end
    end
    json_files_data
  end
end
