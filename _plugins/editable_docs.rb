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
    next unless repo_data.key?("edit_url")
    page_relative_url = page_path.sub(File.join("doc", repo_name), "")
    # Path joins won't look past a potential trailing slash (i.e.
    # won't care about one of the fragments being a partial URL).
    page.data["edit_url"] = File.join(
      repo_data["edit_url"], page_relative_url
    )
  end
end
