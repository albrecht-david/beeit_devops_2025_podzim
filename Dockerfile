FROM ubuntu:22.04


ENV DEBIAN_FRONTEND=noninteractive

#   - sudo (skript volá sudo apt ...)
#   - procps (ps, pro info o procesech)
#   - findutils (find)
#   - grep (grep)
RUN apt-get update && \
    apt-get install -y sudo procps findutils grep && \
    rm -rf /var/lib/apt/lists/*

# Zkopírujeme skript do image
COPY linux_cli.sh /usr/local/bin/linux_cli.sh

# Ujistíme se, že je spustitelný
RUN chmod +x /usr/local/bin/linux_cli.sh

# Nastavíme pracovní adresář
WORKDIR /workspace

# Výchozí příkaz po `docker run linux_cli

CMD ["/usr/local/bin/linux_cli.sh"]

