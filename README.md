# 21it

Open source projects

## Packages

- `reckless-trading-bot` Bitfinex bot for automated trading (reckless)
- `bitfinex-client` Bitfinex client API library for Haskell

## Configuration

Configure Bitfinex user data:

```sh
vi ~/.profile

export BITFINEX_API_KEY="SECRET"
export BITFINEX_PRV_KEY="SECRET"
```

## Quickstart

Requirements:

- Running [Docker/Swarm](https://docs.docker.com/engine/swarm/swarm-tutorial/create-swarm/)
- On Mac you also need `brew install coreutils wget`

Run the following command to spawn `reckless-trading-bot` using prebuilt binaries from github:

```sh
./nix/ds-setup.sh --prebuilt
```

In case where you don't have initialized docker swarm (for example you never used it), you need to run:

```sh
./nix/ds-setup.sh --prebuilt --reset-swarm
```

To build `reckless-trading-bot` from source, make sure Docker have access to reasonable amount of resources (at least 8GB of memory, reasonable storage and CPU capacity). Initial compilation will take a lot of time, CPU, memory, bandwidth and storage, but it's needed to be done only once. Run the following command to build `reckless-trading-bot` from source and run it:

```sh
./nix/ds-setup.sh
```

You can review and change `reckless-trading-bot` settings in `./build/docker-compose.21it.yml` file. Also take a look at the various utility shell scripts in the `./nix/*.sh` location to manage bot and its data.

## Development

Spawn nix-shell:

```sh
./nix/shell.sh
```

Everything following is supposed to be run from inside of spawned nix-shell. Run IDE:

```sh
vi .
```

Run tests:

```sh
stack test --fast --file-watch bitfinex-client
```

Run specific test:

```sh
stack test --fast --file-watch --test-arguments="-m platformStatus" bitfinex-client
```

Run development daemon:

```sh
ghcid
```

## Release

Create new release:

```shell
git tag v0.1.0
git push --tags
```

Delete existing release:

```shell
git tag -d v0.1.0
git push --delete origin v0.1.0
```
