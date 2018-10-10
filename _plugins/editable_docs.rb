Jekyll::Hooks.register :site, :pre_render do |site, payload|
  repositories = site.data["remotes"]["repositories"]
  site.pages.each do |page|
    page_path = page.path
    if page.data.key?("origin_path")
      page_path = page.data["origin_path"]
    end
    next unless page_path.start_with?("doc")
    repo_name, repo_data = repositories.find do |name, data|
      page_path.start_with?(File.join("doc", name))
    end
    next if repo_name.nil? or repo_data.nil?

    # Generate edit url
    edit_relative_url = page_path.sub(File.join("doc", repo_name), "")
    if edit_relative_url.scan(/\//).length > 1
      edit_relative_url = edit_relative_url[0..-12] + page.data["file_extension"]
    else
      edit_relative_url = "/README.md"
    end
    page.data["edit_url"] = generate_edit_url(repo_data, edit_relative_url)
  end
end

def generate_edit_url(repo_data, page_relative_url)
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
    return File.join(edit_url, page_relative_url)
  elsif is_bitbucket
    edit_url = "https://#{host}/#{organization}/#{repo}/src/#{repo_data['version']}"
    return File.join(edit_url, page_relative_url) + "?mode=edit&spa=0&at=#{repo_data['version']}&fileviewer=file-view-default"
  end
end
