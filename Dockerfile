FROM debian:buster-slim
LABEL maintainer="Tomas Jurena <jurenatomas@gmail.com>"

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8

# Default versions
ENV GRAFANA_VERSION=9.2.6

# Grafana database type
ENV GF_DATABASE_TYPE=sqlite3

# Fix bad proxy issue
COPY system/99fixbadproxy /etc/apt/apt.conf.d/99fixbadproxy

WORKDIR /root

SHELL ["/bin/bash", "-c"]

# Clear previous sources
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH='amd64';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armhf';; \
      armel) ARCH='armel';; \
      *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
    esac && \
    rm /var/lib/apt/lists/* -vf \
    # Base packages
    && apt-get -y update \
    && apt-get -y dist-upgrade \
    && apt-get -y install \
        apt-utils \
        ca-certificates \
        curl \
        git \
        htop \
        libfontconfig \
        nano \
        net-tools \
        supervisor \
        wget \
        gnupg \
        libfontconfig1 \
        adduser \
    && curl -sL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs \
    && mkdir -p /var/log/supervisor \
    && rm -rf .profile \
    # Install InfluxDB & telegraf
    && export DISTRIB_ID=$(lsb_release -si) \
    && wget -q https://repos.influxdata.com/influxdb.key \
    && echo "23a1c8836f0afc5ed24e0486339d7cc8f6790b83886c4c96995b88a061c5bb5d influxdb.key" | sha256sum -c && cat influxdb.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdb.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdb.gpg] https://repos.influxdata.com/${DISTRIB_ID,,} stable main" | tee /etc/apt/sources.list.d/influxdata.list > /dev/null \
    && apt-get update \
    && apt-get -y install influxdb2 telegraf \
    # Install Grafana
    && wget -q https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    && dpkg -i grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    && rm grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure Supervisord and base env
COPY supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY bash/profile .profile

# Configure InfluxDB
COPY influxdb/influxdb.conf /etc/influxdb/influxdb.conf
COPY influxdb/ttn-template.yml /etc/influxdb/ttn-template.yml

# Configure Telegraf
COPY telegraf/telegraf.conf /etc/telegraf/telegraf.conf

# Configure Grafana
COPY grafana/grafana.ini /etc/grafana/grafana.ini
COPY grafana/provisioning/datasources/influxdb.yml /etc/grafana/provisioning/datasources/influxdb.yml
COPY grafana/provisioning/dashboards/dashboards.yaml /etc/grafana/provisioning/dashboards/dashboards.yaml
COPY grafana/dashboards/Temperature.json  /var/lib/grafana/dashboards/Temperature.json

COPY run.sh /run.sh
COPY setup.sh /setup.sh

RUN ["chmod", "+x", "/run.sh"]
CMD ["/run.sh"]
