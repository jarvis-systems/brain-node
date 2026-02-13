#!/bin/zsh

API_KEY="jarvis:6c13d58df5771293f5825a50f10ee7005839735f"
CURRENT_DIR=$(pwd)

# -- Git Aliases --

alias untag='cli git:untag'
alias push='cli git:push'
alias tag='cli git:tag'

# -- Upload NODE to Packagist --

echo ">> $CURRENT_DIR"
push -y
curl -X POST -H'Content-Type:application/json' -H"Authorization: Bearer $API_KEY" 'https://packagist.org/api/update-package' -d "{\"repository\":\"https://packagist.org/packages/jarvis-brain/node\"}"
echo ">> DONE"

# -- Upload CLI to Packagist --

echo ">> $CURRENT_DIR/cli"
cd "$CURRENT_DIR/cli" && untag v0.0.1 && push -y && tag v0.0.1 -y
curl -X POST -H'Content-Type:application/json' -H"Authorization: Bearer $API_KEY" 'https://packagist.org/api/update-package' -d "{\"repository\":\"https://packagist.org/packages/jarvis-brain/cli\"}"
echo ">> DONE"

# -- Upload CORE to Packagist --

echo ">> $CURRENT_DIR/core"
cd "$CURRENT_DIR/core" && untag v0.0.2 && push -y && tag v0.0.2 -y
curl -X POST -H'Content-Type:application/json' -H"Authorization: Bearer $API_KEY" 'https://packagist.org/api/update-package' -d "{\"repository\":\"https://packagist.org/packages/jarvis-brain/core\"}"
echo ">> DONE"
