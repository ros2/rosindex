# Custom Jekyll Generator to translate all ReST
# format files found to Markdown format.
class RstAsMarkdown < Jekyll::Generator
  safe true
  priority :high
  attr_reader :config

  INLINE_RST_LINK_REGEX = /\[.*?\]\((.+?\.rst)\)/
  REFERENCE_RST_LINK_REGEX = /^\s*?\[.*?\]: (.+?\.rst)\s*?$/
  RST_LINK_REGEX = /#{INLINE_RST_LINK_REGEX}|#{REFERENCE_RST_LINK_REGEX}/

  CONFIG_KEY = "rst_as_markdown".freeze
  ENABLED_KEY = "enabled".freeze
  INCLUDE_STATIC = "include_static".freeze

  def initialize(config)
    require_relative '../_ruby_libs/text_rendering'
    @config = {
      CONFIG_KEY => {
        ENABLED_KEY => true,
        INCLUDE_STATIC => true
      }
    }.merge(config)
  end

  def generate(site)
    return if disabled?
    if include_static?
      replace_rst_files!(site.static_files) do |file, base, dir, name|
        new_name = name.rpartition('.').first + '.md'
        new_file = Jekyll::StaticFile.new(site, base, dir, new_name)
        File.write(new_file.path, rst_to_md(File.read(file.path)))
        new_file
      end
      replace_rst_links!(site, site.static_files)
    end
    replace_rst_files!(site.pages) do |page, base, dir, name|
      new_name = name.rpartition('.').first + '.md'
      new_page = Jekyll::Page.new(base, dir, new_name)
      File.write(new_page.path, rst_to_md(File.read(page.path)))
      new_page
    end
    replace_rst_links!(site, site.pages)
  end

  def replace_rst_files!(documents, &block)
    documents.collect! do |doc|
      if doc.path.end_with? '.rst'
        base = doc.instance_variable_get('@base')
        dir = doc.instance_variable_get('@dir')
        name = doc.instance_variable_get('@name')
        block.call(doc, base, dir, name)
      else
        doc
      end
    end
  end

  def replace_rst_links!(site, documents)
    cls = Jekyll::Converters::Markdown
    markdown_converter = site.find_converter_instance(cls)
    documents.each do |doc|
      next unless markdown_converter.matches(doc.extname)
      content = File.read(doc.path, :encoding => 'UTF-8')
      modified_content = content.gsub(RST_LINK_REGEX) do |link|
        next if absolute_link? $1
        link.sub($1, $1.sub(/\.rst$/, '.md'))
      end
      File.write(doc.path, modified_content)
    end
  end

  private

  def absolute_link?(link)
    Addressable::URI.parse(link).absolute?
  end
  
  def option(key)
    config[CONFIG_KEY] && config[CONFIG_KEY][key]
  end

  def disabled?
    not option(ENABLED_KEY)
  end

  def include_static?
    option(INCLUDE_STATIC)
  end
end
