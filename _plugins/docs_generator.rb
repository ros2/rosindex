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
      docs_in_repo = Dir.glob(File.join("_remotes", repo_name) + '**/*.{md, rst}', File::FNM_CASEFOLD)
      docfiles_hash[repo_name] = docs_in_repo
    end
    docfiles_hash
  end

  def convert_with_sphinx(docfiles)
    json_files_data = Hash.recursive
    docfiles.each do |repo_name, files|
      repo_path = File.join('_sphinx', 'repos', repo_name)
      command = "sphinx-build -b json -c _sphinx #{repo_path} _sphinx/_build/#{repo_name}"
      pid = Kernel.spawn(command)
      Process.wait pid

      files.each do |file|
        leading_single_quotation = /^'/
        trailing_single_quotation = /'$/
        file.sub!(/#{leading_single_quotation} | #{trailing_single_quotation}/, '')
        name = File.basename(file, File.extname(file))
        if name.scan(/readme/i).length > 0
          name = "index"
        end
        json_file = File.join('_sphinx/_build/', repo_name, name + '.fjson')
        next unless File.file?(json_file)
        json_content = File.read(json_file)
        json_files_data[repo_name][name] = JSON.parse(json_content)
        json_files_data[repo_name][name]["relative_path"] = file

        # Generate HTML tables that were left with markdown syntax by sphinx.
        # Please refer to this issue for more information:
        # https://github.com/rtfd/recommonmark/issues/3
        # Although there's a sphinx-markdown-tables extension now, its
        # functionality is limited and doesn't fit our requirements.
        html_doc = Nokogiri::HTML(JSON.parse(json_content)["body"])
        html_doc.css('p').each do |paragraph|
          if paragraph.content.strip[0] == "|"
            html_table = Kramdown::Document.new(paragraph.inner_html).to_html
            nokogiri_table = Nokogiri::HTML(html_table)
            next unless nokogiri_table.css('td').length > 0
            nokogiri_table.css('table').each do |table|
              # Fixes table by removing the second row that's always filled
              # with hyphens, as a consequence of conversion.
              table.css('tr').each_with_index do |tr, index|
                if index == 1
                  tr.remove
                  break
                end
              end
              table.set_attribute("class", "table table-striped table-dark")
            end
            paragraph.replace(nokogiri_table.to_html)
          end
        end
        json_files_data[repo_name][name]["body"] = html_doc.css('body').first.inner_html 
      end
    end
    json_files_data
  end
end
