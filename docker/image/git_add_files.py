#!/usr/bin/env python3

import argparse
import git
import re


def run(args):
    repo = git.Repo(args.repository_path)

    git_diff_numstat = repo.git.diff(numstat=True)

    # Parse information from git's numstat
    modified_files = {}
    for line in git_diff_numstat.splitlines():
        lines_added, lines_removed, file_path = re.split(r'\t+', line)[:3]

        modified_files[file_path] = {}
        modified_files[file_path]["lines_added"] = int(lines_added)
        modified_files[file_path]["lines_removed"] = int(lines_removed)

    # Filter files that have been modified and contain blacklisted strings
    diff_index = repo.index.diff(None)
    for diff_item in diff_index.iter_change_type('M'):
        filename = diff_item.a_path
        if filename in modified_files:
            diff_string = diff_item.a_blob.data_stream.read().decode('utf-8')
            modified_files[filename]["blacklisted"] = "generated on" in diff_string

    # Add all files to git
    repo.git.add('--all')
    blacklisted_files = []

    # Classify modified files by blacklisted status
    for file, change in modified_files.items():
        if change['lines_added'] == 1 and \
           change['lines_removed'] == 1 and \
           change['blacklisted']:
            blacklisted_files.append(file)

    if blacklisted_files:
        # Remove blacklisted files from git
        repo.index.reset(paths=blacklisted_files)
        repo.git.checkout('.')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Add selected files to git repository.')
    parser.add_argument('repository_path', action='store')
    args = parser.parse_args()
    run(args)
