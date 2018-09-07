config_file=_config.yml
devel_config_file=_config_devel.yml

workdir=..
deploy_dir=$(workdir)/deploy
cache_dir=$(workdir)/deploy_cache
checkout_dir=$(workdir)/checkout

# This target is invoked by a doc_independent job on the ROS buildfarm.
html: build deploy

# Clone a bunch of other repos part of the rosdistro and build the index.
build:
	mkdir -p $(checkout_dir)
	mkdir -p $(deploy_dir)
	mkdir -p $(cache_dir)
	vcs import --input resources.repos $(workdir)
	bundle exec jekyll build --verbose --trace --config=$(config_file)

# deploy assumes download-previous and build were run already
deploy:
	cd $(deploy_dir) && git add --all
	cd $(deploy_dir) && git status
	cd $(deploy_dir) && git commit -m "make deploy by `whoami` on `date`"
	cd $(deploy_dir) && git push --verbose

serve:
	bundle exec jekyll serve --host 0.0.0.0 --trace -d $(deploy_dir) --config=$(config_file) --skip-initial-build

serve-devel:
	bundle exec jekyll serve --host 0.0.0.0 --no-watch -d $(deploy_dir) --trace --config=$(config_file),$(devel_config_file) --skip-initial-build

clean:
	rm -rf $(checkout_dir)
	rm -rf $(deploy_dir)
	rm -rf $(cache_dir)
