# syntax=docker/dockerfile:1.7
ARG FEDORA_VERSION=44
ARG ARCH=x86_64
ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/cosmic-atomic:44
ARG KERNEL_FLAVOR=ogc
ARG KERNEL_VERSION=7.1.8-ogc1.1.fc44.x86_64
ARG COSMIC_EXTRA_COMMIT=66e065728d81eab86171e542dad08fb628c88494
ARG DMS_VERSION=1.5.3
ARG DMS_SHA256=ed543447b98568a092845164ea9cc20538ed8efa421214fba2969ab1b90a3f53
ARG VICINAE_VERSION=0.25.0

FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods
FROM ghcr.io/ublue-os/akmods-nvidia-open:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods-nvidia

FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION} AS cosmic-extra-builder
ARG COSMIC_EXTRA_COMMIT
RUN dnf install -y cargo gcc git && dnf clean all
RUN git clone https://github.com/Drakulix/cosmic-ext-extra-sessions.git /src && \
    cd /src && git checkout "${COSMIC_EXTRA_COMMIT}" && git submodule update --init --recursive && \
    cargo build --manifest-path cosmic-ext-alternative-startup/Cargo.toml --release --locked

FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION} AS dms-release
ARG DMS_VERSION
ARG DMS_SHA256
RUN dnf install -y curl tar gzip && dnf clean all && \
    curl --fail --location --retry 3 \
      "https://github.com/AvengeMedia/DankMaterialShell/releases/download/v${DMS_VERSION}/dms-full-amd64.tar.gz" \
      --output /tmp/dms.tar.gz && \
    echo "${DMS_SHA256}  /tmp/dms.tar.gz" | sha256sum --check && \
    mkdir /out && tar -xzf /tmp/dms.tar.gz -C /out

FROM ${BASE_IMAGE} AS axioma
ARG FEDORA_VERSION
ARG KERNEL_VERSION
ARG VICINAE_VERSION
ARG COSMIC_EXTRA_COMMIT
ARG DMS_VERSION

LABEL org.opencontainers.image.title="Axioma" \
      org.opencontainers.image.description="Fedora COSMIC Atomic with niri and Bazzite-derived gaming optimizations" \
      org.opencontainers.image.source="https://github.com/esteraxiom/axioma" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      io.axioma.fedora-version="${FEDORA_VERSION}" \
      io.axioma.kernel-version="${KERNEL_VERSION}" \
      io.axioma.cosmic-extra-commit="${COSMIC_EXTRA_COMMIT}" \
      io.axioma.dms-version="${DMS_VERSION}"

COPY build /ctx/build
COPY --from=cosmic-extra-builder \
    /src/cosmic-ext-alternative-startup/target/release/cosmic-ext-alternative-startup \
    /usr/bin/cosmic-ext-alternative-startup
COPY --from=dms-release /out/bin/dms-distropkg /usr/bin/dms
COPY --from=dms-release /out/dms /usr/share/quickshell/dms
COPY --from=dms-release /out/completions/completion.bash /usr/share/bash-completion/completions/dms
COPY --from=dms-release /out/completions/completion.fish /usr/share/fish/vendor_completions.d/dms.fish
COPY --from=dms-release /out/completions/completion.zsh /usr/share/zsh/site-functions/_dms

RUN --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=secret,id=GITHUB_TOKEN \
    FEDORA_VERSION="${FEDORA_VERSION}" VICINAE_VERSION="${VICINAE_VERSION}" \
    /ctx/build/configure-image

RUN --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=bind,from=akmods,source=/kernel-rpms,target=/tmp/kernel-rpms \
    --mount=type=bind,from=akmods,source=/rpms/common,target=/tmp/akmods-common \
    --mount=type=bind,from=akmods,source=/rpms/kmods,target=/tmp/akmods-kmods \
    chmod 0755 /ctx/build/install-kernel-akmods /ctx/build/configure-image && \
    /ctx/build/install-kernel-akmods

RUN --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=bind,from=akmods-nvidia,source=/rpms,target=/tmp/akmods-nvidia \
    --mount=type=secret,id=GITHUB_TOKEN \
    set -euo pipefail; \
    dnf5 remove -y nvidia-gpu-firmware 2>/dev/null || true; \
    IMAGE_NAME=SKIP_PACKAGE_INSTALL AKMODNV_PATH=/tmp/akmods-nvidia MULTILIB=1 \
      /tmp/akmods-nvidia/ublue-os/nvidia-install.sh; \
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json; \
    ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so; \
    dnf5 clean all

COPY files /
COPY tests/image-assertions.sh /usr/share/axioma/tests/image-assertions.sh

RUN chmod 0755 /usr/bin/start-axioma-cosmic-niri /usr/bin/axioma-* \
      /usr/lib/tuned/profiles/axioma-*/script.sh \
      /usr/share/axioma/tests/image-assertions.sh && \
    chmod 0644 /usr/share/wayland-sessions/*.desktop && \
    systemctl enable axioma-flatpak-setup.service dev-hugepages1G.mount && \
    systemctl --global enable axioma-welcome.service && \
    kernel="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')" && \
    test "$kernel" = "${KERNEL_VERSION}" && \
    dracut --no-hostonly --kver "$kernel" --reproducible --zstd \
      --add 'ostree fido2' --force "/usr/lib/modules/${kernel}/initramfs.img" && \
    bootc container lint
