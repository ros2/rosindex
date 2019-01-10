#!/usr/bin/env python3

import argparse
import git
import re

parser = argparse.ArgumentParser(
    description='Add selected files to git repository.')
parser.add_argument('repository_path', action='store')
args = parser.parse_args()
repo = git.Repo(args.repository_path)

git_diff_numstat = repo.git.diff(numstat=True)
git_diff = repo.git.diff().encode("utf-8")

# Parse information from git's numstat
modified_files = {}
for line in git_diff_numstat.splitlines():
    tmp = re.split(r'\t+', line)
    modified_files[tmp[2]] = {}
    modified_files[tmp[2]]["lines_added"] = int(tmp[0])
    modified_files[tmp[2]]["lines_removed"] = int(tmp[1])

# Filter files that have been modified and contain blacklisted strings
diff_index = repo.index.diff(None)
for diff_item in diff_index.iter_change_type('M'):
    filename = diff_item.a_path
    if filename in modified_files:
        modified_files[filename]["blacklisted"] = "generated on" in diff_item.a_blob.data_stream.read(
        ).decode('utf-8')

# Add all files to git
repo.git.add('--all')
blacklisted_files = []

# Classify modified files by blacklisted status
for file, change in modified_files.items():
    if change['lines_added'] == 1 and \
       change['lines_removed'] == 1 and \
       change['blacklisted']:
        blacklisted_files.append(file)

# Remove blacklisted files from git
repo.git.reset(blacklisted_files)
