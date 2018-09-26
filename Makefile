devel_config_file=_config_devel.yml

workdir=..
data_dir=_data
docs_dir=doc

remotes_dir=_remotes
remotes_file=$(data_dir)/remotes.yml
deploy_dir=$(remotes_dir)/deploy
cache_dir=$(deploy_dir)/cache

config_file=_config.yml
index_file=index.yml
discover_config=_config/discover.yml
update_config=_config/update.yml
scrape_config=_config/scrape.yml
search_config=_config/search_index.yml

build: download-previous discover update scrape search-index

# This target is invoked by a doc_independent job on the ROS buildfarm.
html: build deploy

download-previous:
	mkdir -p $(deploy_dir)
	mkdir -p $(docs_dir)
	mkdir -p $(remotes_dir)
	vcs import --input $(remotes_file) --force $(remotes_dir)

discover:
	bundle exec jekyll build --verbose --trace -d $(deploy_dir) --config=$(config_file),$(index_file),$(discover_config)

update:
	bundle exec jekyll build --verbose --trace -d $(deploy_dir) --config=$(config_file),$(index_file),$(update_config)

scrape:
	bundle exec jekyll build --verbose --trace -d $(deploy_dir) --config=$(config_file),$(index_file),$(scrape_config)

search-index:
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
	bundle exec jekyll serve --host 0.0.0.0 --watch -d $(deploy_dir) --trace --config=$(config_file),$(devel_config_file),$(index_file) --skip-initial-build

clean:
	rm -rf $(deploy_dir)
