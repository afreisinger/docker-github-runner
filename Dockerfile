ARG FROM=debian:bookworm
FROM ${FROM}

ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_VERSION="2.26.2"
ARG GH_RUNNER_VERSION
ARG DOCKER_COMPOSE_VERSION="1.27.4"
ARG BUILD_DATE
ARG VCS_REF

ENV RUNNER_NAME=""
ENV RUNNER_WORK_DIRECTORY="_work"
ENV RUNNER_TOKEN=""
ENV RUNNER_REPOSITORY_URL=""
ENV RUNNER_LABELS=""
ENV RUNNER_ALLOW_RUNASROOT=true
ENV GITHUB_ACCESS_TOKEN=""
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache

# Labels
LABEL maintainer="afreisinger@gmail.com" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=${BUILD_DATE} \
      org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.name="afreisinger/github-runner" \
      org.label-schema.description="Dockerized GitHub Actions runner." \
      org.label-schema.url="https://github.com/afreisinger/docker-github-runner" \
      org.label-schema.vcs-url="https://github.com/afreisinger/docker-github-runner" \
      org.label-schema.vendor="Adrian Freisinger" \
      org.label-schema.docker.cmd="docker run -it afreisinger/github-runner:latest"

# Instalación de dependencias
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget unzip jq iputils-ping sudo supervisor \
        ca-certificates apt-transport-https gettext \
        build-essential zlib1g-dev liblttng-ust1 libcurl4-openssl-dev openssh-client git \
        libssl3 python3 python3-pip python3-venv python3-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Crear enlace simbólico de 'python3' a 'python'
RUN ln -s /usr/bin/python3 /usr/bin/python

# Copiar configuración de Supervisor
COPY --chown=root:root supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Instalar Docker CLI
RUN curl -fsSL https://get.docker.com | sh

# Instalar Docker-Compose
RUN curl -L -o /usr/local/bin/docker-compose \
    "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" && \
    chmod +x /usr/local/bin/docker-compose

# Crear directorios necesarios
RUN mkdir -p /home/runner ${AGENT_TOOLSDIRECTORY}

WORKDIR /home/runner

# Instalación del GitHub Actions Runner
RUN GH_RUNNER_VERSION=${GH_RUNNER_VERSION:-$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | grep tag_name | sed -E 's/.*\"v([^\"]+)\".*/\1/')} && \
    curl -L -O https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz && \
    tar -zxf actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz && \
    rm -f actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz && \
    ./bin/installdependencies.sh && \
    chown -R root: /home/runner

# Copiar el script de entrada y darle permisos de ejecución
COPY --chown=root:root entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Agregar un HEALTHCHECK para monitorear el estado del contenedor
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD pgrep -f "supervisord" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]