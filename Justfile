set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

validate:
    bash tests/validate-repo.sh

build tag="testing":
    #!/usr/bin/bash
    set -euo pipefail
    set -a
    source build/versions.env
    set +a
    podman build --pull=newer --secret id=GITHUB_TOKEN,env=GITHUB_TOKEN \
      --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
      --build-arg "ARCH=${ARCH}" \
      --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
      --build-arg "KERNEL_FLAVOR=${KERNEL_FLAVOR}" \
      --build-arg "KERNEL_VERSION=${KERNEL_VERSION}" \
      --build-arg "COSMIC_EXTRA_COMMIT=${COSMIC_EXTRA_COMMIT}" \
      --build-arg "DMS_VERSION=${DMS_VERSION}" \
      --build-arg "DMS_SHA256=${DMS_SHA256}" \
      --build-arg "VICINAE_VERSION=${VICINAE_VERSION}" \
      --label "org.opencontainers.image.revision=$(git rev-parse HEAD)" \
      --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --tag "axioma:{{tag}}" --file Containerfile .

image-test tag="testing":
    podman run --rm --entrypoint /usr/bin/bash "axioma:{{tag}}" /usr/share/axioma/tests/image-assertions.sh

