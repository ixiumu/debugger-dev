#!/bin/bash -e
#
# GNU Bash required for process substitution `<()` later.
#
# Environment variables:
#
# - `GITHUB_ACTION_PATH`: path to this repository.
# - `GITHUB_ACTOR`: GitHub username of whoever triggered the action.
# - `GITHUB_WORKSPACE`: default path for the workflow.
#

notify_func() {
    cat
}

SCRIPT_PATH=$(dirname $(readlink -f "$0"))

# Check non-coreutils dependencies
EXTERNAL_DEPS="curl jq ssh-keygen"

for dep in $EXTERNAL_DEPS; do
    if ! command -v "$dep" > /dev/null 2>&1; then
       echo "Command $dep not installed on the system!" >&2
       exit 1
    fi
done

cd "$GITHUB_ACTION_PATH"

cloudflared_url=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
echo "Downloading \`cloudflared\` from <$cloudflared_url>..."
curl --location --silent --output cloudflared "$cloudflared_url"
chmod +x cloudflared

curl -s "https://api.github.com/users/$GITHUB_ACTOR/keys" | jq -r '.[].key' > authorized_keys

if grep -q . authorized_keys; then
    echo "Configured SSH key(s) for user: $GITHUB_ACTOR"
else
    echo "No SSH key found for user: $GITHUB_ACTOR"
    echo "Setting SSH password..."

    password=$(head -c 16 /dev/urandom | base64 | tr -cd '[:alnum:]' | head -c 16)
    (echo "$password"; echo "$password") | sudo passwd "$USER"
fi

# `-q` is to make it quiet, `-N ''` is for empty passphrase
echo 'Creating SSH server key...'
ssh-keygen -q -f ssh_host_rsa_key -N ''
echo "$fingerprint"

echo 'Creating SSH server config...'
sed "s,\$PWD,$PWD,;s,\$USER,$USER," "$SCRIPT_PATH/sshd_config.template" > sshd_config

echo 'Starting SSH server...'
/usr/sbin/sshd -f sshd_config -D &
sshd_pid=$!

#echo 'Starting tmux session...'
#(cd "$GITHUB_WORKSPACE" && tmux new-session -d -s debug)

# Use `sed -u` (unbuffered) otherwise logs don't show up in the UI
echo 'Starting Cloudflare tunnel...'
./cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARED_TUNNEL_TOKEN" 2>&1 | tee cloudflared.log | sed -u 's/^/cloudflared: /' &
cloudflared_pid=$!

#
# The `channel` argument is not used but needs to be passed.
#
# `wait-for` will hang until we call `tmux wait-for -S channel` (which we
# don't) but it'll also exit when all tmux sessions are over, which is
# fine with us!
#
#tmux wait-for channel

"$SCRIPT_PATH/wait.sh"

echo 'Session ended'

kill "$cloudflared_pid"
kill "$sshd_pid"
