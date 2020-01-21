#!/bin/bash

# Given a regex, return the most recent git tag which matches
function getLatestTagMatching() {
  regex=$1
  echo $(git describe --match "$regex" --abbrev=0 --tags `git rev-list --tags --max-count=1`)
}

# Given the variable (maven property) used to hold a module's version, return the
# version in the form of Major.Minor (no '-SNAPSHOT')
function getMajorMinorVersionOfModule() {
  module_version_variable_name=$1
  current_version=$(mvn help:evaluate -Dexpression="$module_version_variable_name" -q -DforceStdout)
  echo "${current_version/-SNAPSHOT/}"
}

# Arguments:
# 1) module_name: A friendly name for the module.  Used for logging
# 2) module_version_variable_name: The name of the maven property used to hold this module's version
# 3) module_tag_regex: A regex which describes the git tags used for this module
# 4) module_dir: The directory in which the module is held.  Used to count how many changes have
#                been made in this module since the last tag
function setVersionForModule() {
  module_name=$1
  module_version_variable_name=$2
  module_tag_regex=$3
  module_dir=$4

  current_version_major_minor=$(getMajorMinorVersionOfModule "$module_version_variable_name")
  echo "Current $module_name version is ${current_version_major_minor}"

  most_recent_tag=$(getLatestTagMatching "$module_tag_regex")
  echo "Most recent $module_name tag is $most_recent_tag"

  # Get the hash of the commit corresponding to the most recent change to be used in the version
  most_recent_change_hash_short=$(git log --format=%h --max-count=1 $most_recent_tag..HEAD $module_dir)
  echo "Most recent commit in $module_name is $most_recent_change_hash_short"
  # xargs is used to trim whitespace from the result
  patch_num=$(git log --format=%H $most_recent_tag..HEAD $module_dir | wc -l | xargs)
  echo "Calculated $module_name patch num from $most_recent_change_hash_short is $patch_num"
  new_version="$current_version_major_minor-$patch_num-g$most_recent_change_hash_short"
  echo "$module_name new version is $new_version"

  if ! $DRY_RUN ; then
    echo "Setting maven versions"
    mvn versions:set-property -Dproperty=$module_version_variable_name -DnewVersion=$new_version
  fi
}

for i in "$@" ; do
    if [[ $i == "--dry-run" ]] ; then
        echo "====Doing a dry run===="
        DRY_RUN=true
        break
    fi
done

if [ -z "$DRY_RUN" ]; then
  DRY_RUN=false
fi

if [ ! -d "./rtp" ] || [ ! -d "./jmt" ] || [ ! -d "./jvb" ] ; then
  echo "Can't find rtp, jmt, or jvb dirs.  Did you run this from the top-level?"
  exit 1
fi

setVersionForModule "RTP" "rtp.version" "rtp*" "rtp/"
setVersionForModule "JMT" "jmt.version" "jmt*" "jmt/"
setVersionForModule "JVB" "jvb.version" "jvb*" "jvb/"
