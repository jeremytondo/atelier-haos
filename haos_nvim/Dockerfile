FROM ubuntu:24.04

ARG BUILD_VERSION=dev
ARG BUILD_ARCH=amd64
ARG ATELIER_REF=aa2ed0ac79598d502df96d72de6456a39a313c0c
ARG NODE_VERSION=20.19.0
ARG FZF_VERSION=0.71.0

LABEL io.hass.version="${BUILD_VERSION}" \
      io.hass.type="addon" \
      io.hass.arch="${BUILD_ARCH}"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      ncurses-bin \
      openssh-server \
      zsh \
      git \
      curl \
      ca-certificates \
      jq \
      locales \
      sudo \
      stow \
      ripgrep \
      bat \
      fd-find \
      eza \
      zoxide \
      wget \
      xz-utils \
      unzip \
      less \
      procps \
      uuid-runtime && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

COPY terminfo/xterm-ghostty.terminfo /tmp/xterm-ghostty.terminfo

RUN tic -x -o /usr/share/terminfo /tmp/xterm-ghostty.terminfo && \
    rm -f /tmp/xterm-ghostty.terminfo

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
      amd64) node_arch="x64" ;; \
      arm64) node_arch="arm64" ;; \
      *) echo "Unsupported architecture for Node.js: ${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner; \
    rm -f /tmp/node.tar.xz; \
    node --version; \
    npm --version

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
      amd64) fzf_asset="fzf-${FZF_VERSION}-linux_amd64.tar.gz" ;; \
      arm64) fzf_asset="fzf-${FZF_VERSION}-linux_arm64.tar.gz" ;; \
      *) echo "Unsupported architecture for fzf: ${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${fzf_asset}" -o /tmp/fzf.tar.gz; \
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf_${FZF_VERSION}_checksums.txt" -o /tmp/fzf_checksums.txt; \
    checksum="$(awk '/  '"${fzf_asset}"'$/ { print $1 }' /tmp/fzf_checksums.txt)"; \
    [ -n "${checksum}" ]; \
    printf '%s  %s\n' "${checksum}" /tmp/fzf.tar.gz | sha256sum -c -; \
    tar -xzf /tmp/fzf.tar.gz -C /usr/local/bin fzf; \
    chmod 0755 /usr/local/bin/fzf; \
    rm -f /tmp/fzf.tar.gz /tmp/fzf_checksums.txt; \
    fzf --version

RUN npm install -g @openai/codex @anthropic-ai/claude-code && \
    npm cache clean --force

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
      amd64) nvim_arch="x86_64" ;; \
      arm64) nvim_arch="arm64" ;; \
      *) echo "Unsupported architecture for Neovim: ${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${nvim_arch}.tar.gz" -o /tmp/nvim.tar.gz; \
    tar -xzf /tmp/nvim.tar.gz -C /opt; \
    ln -sf "/opt/nvim-linux-${nvim_arch}/bin/nvim" /usr/local/bin/nvim; \
    ln -sf /usr/local/bin/nvim /usr/local/bin/vim; \
    rm -f /tmp/nvim.tar.gz; \
    nvim --version | head -n 1

RUN git init /opt/atelier && \
    cd /opt/atelier && \
    git remote add origin https://github.com/jeremytondo/atelier && \
    git fetch --depth 1 origin "${ATELIER_REF}" && \
    git checkout --detach FETCH_HEAD

RUN git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions /usr/local/share/zsh-autosuggestions

RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd && \
    ln -sf /usr/bin/batcat /usr/local/bin/bat

COPY scripts/bootstrap-home.sh /opt/ha_nvim/scripts/bootstrap-home.sh
COPY scripts/write-sshd-config.sh /opt/ha_nvim/scripts/write-sshd-config.sh
COPY scripts/atelier-shell /usr/local/bin/atelier-shell
COPY run.sh /run.sh

RUN chmod 0755 \
      /opt/ha_nvim/scripts/bootstrap-home.sh \
      /opt/ha_nvim/scripts/write-sshd-config.sh \
      /usr/local/bin/atelier-shell \
      /run.sh && \
    install -d -m 0755 /data/home /data/ssh /var/run/sshd && \
    useradd \
      --create-home \
      --home-dir /data/home/atelier \
      --shell /usr/local/bin/atelier-shell \
      atelier && \
    passwd -d atelier && \
    chown -R atelier:atelier /data/home && \
    printf 'atelier ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/atelier && \
    chmod 0440 /etc/sudoers.d/atelier

EXPOSE 2222

CMD ["/run.sh"]
