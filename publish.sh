#!/bin/sh

setup_git() {
  git config --global user.email "travis@travis-ci.org"
  git config --global user.name "Travis CI"
}

remove_unneeded_files() {
  # from git
  git rm .travis.yml
  git rm publish.sh
  git rm -r query
  # from build
  rm sqlitebiter.deb  
  rm *.sqlite
  rm *.xlsx
}

commit_website_files() {
  # fetch origin:gh-pages branch
  git fetch origin
  git checkout -b gh-pages
  # add & commit everything new
  git add --all
  git commit --message "Update. [Travis build: $TRAVIS_BUILD_NUMBER] [skip ci]"
}

upload_files() {
  # make sure we have a the Github Token
  if [ -z $GH_TOKEN ]; then
    echo "Please set your Github token as secret GH_TOKEN env var."
    exit 1
  fi
  # git push
  git remote add origin-pages https://${GH_TOKEN}@github.com/jakoch/wikifolio_universe > /dev/null 2>&1
  git push -f --set-upstream origin-pages gh-pages > /dev/null 2>&1
}

setup_git
remove_unneeded_files
commit_website_files
upload_files