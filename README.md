# Atelier HAOS

`atelier_haos` is a local-first Home Assistant add-on that provides an
[Atelier-based](https://github.com/jeremytondo/atelier) development environment over SSH for managing and editing Home
Assistant configurations. The add-on includes Neovim, Codex, and Claude Code, backed by a persistent home
directory under `/data` and a writable mount of the real Home Assistant config
at `/homeassistant`.

> [!WARNING]
> Don't use this add-on. No, really. You could do some serious damage to your Home Assistant config if you don't know what you're doing.

## Install From GitHub

1. Push this repository to GitHub.
2. In Home Assistant, open **Settings -> Add-ons -> Add-on Store**.
3. Open the overflow menu, choose **Repositories**, and add your repository URL.
4. Install **Atelier HAOS** from the store.
5. Paste one or more SSH public keys into `authorized_keys` in the add-on config.
6. Start the add-on and connect with `ssh -p 2222 atelier@homeassistant.local`.

## Install From `/addons/local`

1. Copy this repository's `atelier_haos/` directory to
   `/addons/local/atelier_haos` on the Home Assistant host.
2. In the add-on store, refresh local add-ons.
3. Install **Atelier HAOS**.
4. Set `authorized_keys` in the add-on config and start it.

## Local Docker Smoke Test

Create a local data directory and write `options.json` at the root of that
directory before starting the container. The container reads
`/data/options.json`, so if you mount `/tmp/atelier_haos_data` to `/data`, the
file must exist at `/tmp/atelier_haos_data/options.json` on the host.

```json
{
  "authorized_keys": [
    "ssh-ed25519 AAAA... your-key"
  ],
  "log_level": "info"
}
```

Also create a writable directory to stand in for the Home Assistant config
mount. For the smoke test, this can be an empty folder; the container only
requires that `/homeassistant` exists and is writable.

Build and run:

```bash
docker build -t atelier-haos ./atelier_haos
docker run --rm -it \
  -v ../homeassistant-tmp:/homeassistant \
  -v ../data-tmp:/data \
  -p 2222:2222 \
  atelier-haos
```

Then connect with:

```bash
ssh -p 2222 atelier@127.0.0.1
```

## Persistence Model

- Persistent user home: `/data/home/atelier`
- Persistent SSH host keys and rendered auth keys: `/data/ssh`
- Live Home Assistant config mount: `/homeassistant`
- User workspace entrypoint: `~/workspace/homeassistant -> /homeassistant`

Additional add-on details live in [`atelier_haos/DOCS.md`](atelier_haos/DOCS.md).
