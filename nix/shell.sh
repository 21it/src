#!/bin/sh

set -e

THIS_DIR="$(dirname "$(realpath "$0")")"
CONTAINER="nixos/nix:2.3.12"
USER="${USER:-user}"
NIX_CONF="http2 = false
trusted-users = root $USER
extra-substituters = https://cache.nixos.org https://hydra.iohk.io
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=
"
BITFINEX_API_KEY="${BITFINEX_API_KEY:-TODO}"
BITFINEX_PRV_KEY="${BITFINEX_PRV_KEY:-TODO}"
TELEGRAM_BOT_KEY="${TELEGRAM_BOT_KEY:-TODO}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-TODO}"

MINISHELL="false"
CHOWN_CMD="true"
TRACE_FLAGS="--show-trace -v"
if [ -z "$*" ]; then
  true
else
  for arg in "$@"
  do
    case $arg in
      -m|--mini|--minishell)
        MINISHELL="true"
        shift
        ;;
      -g|--github|--github-actions)
        CHOWN_CMD="chown -R $USER:$USER ."
        TRACE_FLAGS=""
        shift
        ;;
      *)
        break
        ;;
    esac
  done
fi
NIX_EXTRA_ARGS="$@"

USE_TTY=""
test -t 1 && USE_TTY="-t"
docker run -i $USE_TTY --rm \
  -v "$THIS_DIR/..:/app" \
  -v "nix-$USER:/nix" \
  -v "nix-home-$USER:/home/$USER" \
  --security-opt seccomp=unconfined \
  -w "/app" "$CONTAINER" \
  sh -c "
  echo '$CONTAINER ==> running as $USER' &&
  adduser $USER -D &&
  $CHOWN_CMD &&
  echo \"$NIX_CONF\" >> /etc/nix/nix.conf &&
  (nix-daemon &) &&
  sleep 1 &&
  su $USER -c \"NIX_REMOTE=daemon \
      nix-shell \
      ./nix/shell.nix \
      --pure $TRACE_FLAGS \
      --arg minishell $MINISHELL \
      --argstr bitfinexApiKey $BITFINEX_API_KEY \
      --argstr bitfinexPrvKey $BITFINEX_PRV_KEY \
      --argstr telegramBotKey $TELEGRAM_BOT_KEY \
      --argstr telegramChatId $TELEGRAM_CHAT_ID \
      $NIX_EXTRA_ARGS\"
  "
