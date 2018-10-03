require 'json'

repos = Hash.new
repos["ros2_overview"] = { "description" => "ROS2 Overview" }
repos["prueba"] = { "description" => "ROS2 Overview" }
remotes_dir = "/home/alexis/rosindex/_remotes/"

class Hash
  def self.recursive
    new { |hash, key| hash[key] = recursive }
  end
end

def search_docfiles(doc_repos_hash, remotes_dir)
  docfiles_hash = Hash.new
  doc_repos_hash.each do |repo_name, repo|
    files_in_repo = Array.new
    Dir.glob(File.join(remotes_dir, repo_name) + '**/*.{md, rst}', File::FNM_CASEFOLD) do |doc_relpath|
      files_in_repo.push(doc_relpath)
    end
    docfiles_hash[repo_name] = files_in_repo
  end
  docfiles_hash
end

def convert_with_sphinx(repos, remotes_dir)
  json_files_data = Hash.recursive
  search_docfiles(repos, remotes_dir).each do |repo_name, files|
    files.each do |file|
      command = "sphinx-build -b json -c _sphinx _remotes/#{repo_name} _sphinx/_build #{file}"
      name = File.basename(file, File.extname(file))
      #pid = Kernel.spawn(command)
      #Process.wait pid
      json_file = File.join('_sphinx/_build/', name + '.fjson')
      next unless File.file?(json_file)
      json_content = File.read(json_file)

      json_files_data[repo_name][name] = JSON.parse(json_content)
    end
  end
  json_files_data
end

convert_with_sphinx(repos, remotes_dir).each do |thing|
  puts thing
end