devel_config_file=_config_devel.yml

data_dir=_data
cache_dir=_cache
remotes_dir=_remotes
plugins_data_dir=_plugins_data
remotes_file=$(data_dir)/remotes.yml
deploy_dir=$(remotes_dir)/deploy

config_file=_config.yml
index_file=index.yml
discover_config=_config/discover.yml
update_config=_config/update.yml
scrape_config=_config/scrape.yml
search_config=_config/search_index.yml

# This target is invoked by a doc_independent job on the ROS buildfarm.
html: build deploy

download-previous:
	mkdir -p $(remotes_dir)
	vcs import --input $(remotes_file) --force $(remotes_dir)

build: download-previous
	bundle exec jekyll build --verbose --trace -d $(deploy_dir) --config=$(config_file),$(index_file)

discover: download-previous
	bundle exec jekyll build --verbose --trace -d $(deploy_dir) --config=$(config_file),$(index_file),$(discover_config)

update: download-previous
	bundle exec jekyll build --verbose --trace -d $(deploy_dir) --config=$(config_file),$(index_file),$(update_config)

scrape: download-previous
	bundle exec jekyll build --verbose --trace -d $(deploy_dir) --config=$(config_file),$(index_file),$(scrape_config)

search-index: download-previous
	bundle exec jekyll build --verbose --trace -d $(deploy_dir) --config=$(config_file),$(index_file),$(search_config)

# deploy assumes build has run already
deploy:
	cd $(deploy_dir) && git add --all
	cd $(deploy_dir) && git status
	cd $(deploy_dir) && git commit -m "make deploy by `whoami` on `date`"
	cd $(deploy_dir) && git push --verbose

serve:
	bundle exec jekyll serve --host 0.0.0.0 --trace -d $(deploy_dir) --config=$(config_file),$(index_file) --skip-initial-build

serve-devel:
	bundle exec jekyll serve --host 0.0.0.0 --no-watch -d $(deploy_dir) --trace --config=$(config_file),$(devel_config_file),$(index_file) --skip-initial-build

clean-sources:
	rm -rf $(plugins_data_dir)
	rm -rf $(remotes_dir)

clean-cache:
	rm -rf $(cache_dir)

clean: clean-cache clean-sources

