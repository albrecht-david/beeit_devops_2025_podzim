########## BASE STAGE ##########
FROM ubuntu:22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# Nainstalujeme nástroje potřebné pro linux_cli.sh
RUN apt-get update && \
    apt-get install -y sudo procps findutils grep && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

########## TESTS STAGE ##########
FROM base AS tests

# Zkopírujeme skript a testovací skript do testovacího image
COPY linux_cli.sh /usr/local/bin/linux_cli.sh
COPY test_linux_cli.sh /usr/local/bin/test_linux_cli.sh

RUN chmod +x /usr/local/bin/linux_cli.sh /usr/local/bin/test_linux_cli.sh

# Spuštění testů - pokud se něco rozbije, build skončí chybou
RUN /usr/local/bin/test_linux_cli.sh

########## PRODUCTION STAGE ##########
FROM base AS production

# Do produkčního image už dáváme jen samotný CLI skript
COPY linux_cli.sh /usr/local/bin/linux_cli.sh
RUN chmod +x /usr/local/bin/linux_cli.sh

WORKDIR /workspace

# ENTRYPOINT = vždy se spustí linux_cli.sh
ENTRYPOINT ["/usr/local/bin/linux_cli.sh"]

# CMD = default argumenty (žádné) → bez parametrů se spustí menu
CMD []
