#!/bin/zsh

API_KEY="jarvis:6c13d58df5771293f5825a50f10ee7005839735f"
CURRENT_DIR=$(pwd)

# -- Git Aliases --

alias untag='cli git:untag'
alias push='cli git:push'
alias tag='cli git:tag'

# -- Upload NODE to Packagist --

GITHUB_REPO=$(git config --get remote.origin.url | sed -e 's/.*github.com[:/]\(.*\)\.git/\1/')
GITHUB_REPO="https://github.com/$GITHUB_REPO"

echo $GITHUB_REPO

push -y
curl -X POST -H'Content-Type:application/json' -H"Authorization: Bearer $API_KEY" 'https://packagist.org/api/update-package' -d "{\"repository\":\"$GITHUB_REPO\"}"


# -- Upload CLI to Packagist --

GITHUB_REPO=$(cd "$CURRENT_DIR/cli" && git config --get remote.origin.url | sed -e 's/.*github.com[:/]\(.*\)\.git/\1/')
GITHUB_REPO="https://github.com/$GITHUB_REPO"

echo $GITHUB_REPO

cd "$CURRENT_DIR/cli" && untag v0.0.1 && push -y && tag v0.0.1 -y
curl -X POST -H'Content-Type:application/json' -H"Authorization: Bearer $API_KEY" 'https://packagist.org/api/update-package' -d "{\"repository\":\"$GITHUB_REPO\"}"


# -- Upload CORE to Packagist --

GITHUB_REPO=$(cd "$CURRENT_DIR/core" && git config --get remote.origin.url | sed -e 's/.*github.com[:/]\(.*\)\.git/\1/')
GITHUB_REPO="https://github.com/$GITHUB_REPO"

echo $GITHUB_REPO

cd "$CURRENT_DIR/core" && untag v0.0.1 && push -y && tag v0.0.1 -y
curl -X POST -H'Content-Type:application/json' -H"Authorization: Bearer $API_KEY" 'https://packagist.org/api/update-package' -d "{\"repository\":\"$GITHUB_REPO\"}"
