Jekyll::Hooks.register :site, :pre_render do |site, payload|
  repositories = site.data["remotes"]["repositories"]
  site.pages.each do |page|
    page_path = page.path
    if page.data.key?("origin_path")
      page_path = page.data["origin_path"]
    end
    next unless page_path.start_with?("doc")
    repo_name, repo_data = repositories.find do |name, data|
      page_path.start_with? (File.join("doc", name))
    end
    next if repo_name.nil? or repo_data.nil?

    # Generate edit url
    page_relative_url = page_path.sub(File.join("doc", repo_name), "")
    page.data["edit_url"] = generate_edit_url(repo_data, page_relative_url)
  end
end

def generate_edit_url(repo_data, page_relative_url)
  https = repo_data['url'].include? "https"
  github = repo_data['url'].include? "github.com"
  bitbucket = repo_data['url'].include? "bitbucket.org"

  unless github or bitbucket
    raise ValueError("Cannot generate edition URL. Unknown organization for repository: #{repo_data['url']}")
  end
  
  if https
    uri = URI(repo_data['url'])
    organization, repo = uri.path.split("/").reject { |c| c.empty? }
    if repo.end_with? ".git" then repo.chomp!(".git") end
    if github
      edit_url = "https://#{uri.host}/#{organization}/#{repo}/edit/#{repo_data['version']}"
      return File.join(edit_url, page_relative_url)
    elsif bitbucket
      edit_url = "https://#{uri.host}/#{organization}/#{repo}/src/#{repo_data['version']}"
      return File.join(edit_url, page_relative_url) + "?mode=edit&spa=0&at=#{repo_data['version']}&fileviewer=file-view-default"
    end
  else # ssh
    if github
      host = repo_data['url'].split("@")[1].split(":")[0]
      organization, repo = repo_data['url'].split("@")[1].split(":")[1].split("/")
      if repo.end_with? ".git" then repo.chomp!(".git") end
      edit_url = "https://#{host}/#{organization}/#{repo}/edit/#{repo_data['version']}"
      return File.join(edit_url, page_relative_url)
    elsif bitbucket
      host = repo_data['url'].split("@")[1].split(":")[0]
      organization, repo = repo_data['url'].split("@")[1].split(":")[1].split("/")
      if repo.end_with? ".git" then repo.chomp!(".git") end
      edit_url = "https://#{host}/#{organization}/#{repo}/src/#{repo_data['version']}"
      return File.join(edit_url, page_relative_url) + "?mode=edit&spa=0&at=#{repo_data['version']}&fileviewer=file-view-default"
    end
  end
end
