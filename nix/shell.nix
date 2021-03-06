let nixpkgs = import ./nixpkgs.nix;
in
{
  pkgs ? import nixpkgs {
    overlays = import ./overlay.nix {
      inherit minishell;
    };
  },
  minishell ? false,
  bitfinexApiKey ? "TODO",
  bitfinexPrvKey ? "TODO",
  telegramBotKey ? "TODO",
  telegramChatId ? "TODO"
}:
with pkgs;

stdenv.mkDerivation {
  name = "21it";
  buildInputs = [
    ide21
    postgresql
    nix-bundle
    # crypto
    secp256k1
    pkg-config
    # charts
    gnuplot
    librsvg
    # neural
    blas
    lapack
    protobuf
  ];
  TERM="xterm-256color";
  LC_ALL="C.UTF-8";
  GIT_SSL_CAINFO="${cacert}/etc/ssl/certs/ca-bundle.crt";
  NIX_SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt";
  NIX_PATH="/nix/var/nix/profiles/per-user/root/channels";
  BITFINEX_API_KEY=bitfinexApiKey;
  BITFINEX_PRV_KEY=bitfinexPrvKey;
  TELEGRAM_BOT_KEY=telegramBotKey;
  TELEGRAM_CHAT_ID=telegramChatId;
  shellHook =
    if minishell
    then ""
    else ''

      mkdir -p /app/build

      (cd /app/bitfinex-client/nix/ && cabal2nix ./.. > ./pkg.nix)
      (cd /app/reckless-trading-bot/nix/ && cabal2nix ./.. > ./pkg.nix)

      source /app/reckless-trading-bot/nix/export-test-envs.sh
      /app/reckless-trading-bot/nix/spawn-test-deps.sh

    '';
}
