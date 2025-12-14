FROM ubuntu:22.04

# Nebudeme chtít interaktivní otázky z aptu
ENV DEBIAN_FRONTEND=noninteractive

# Nainstalujeme nástroje, které skript používá:
#  - sudo   (skript volá sudo apt ...)
#  - procps (ps, top - info o procesech)
#  - findutils (find)
#  - grep  (grep)
RUN apt-get update && \
    apt-get install -y sudo procps findutils grep && \
    rm -rf /var/lib/apt/lists/*

# Zkopírujeme tvůj CLI skript do image
COPY linux_cli.sh /usr/local/bin/linux_cli.sh

# Ujistíme se, že je spustitelný
RUN chmod +x /usr/local/bin/linux_cli.sh

# Pracovní adresář (můžeš sem mapovat volume z hosta)
WORKDIR /workspace

# ENTRYPOINT = vždy se spustí tvůj skript
ENTRYPOINT ["/usr/local/bin/linux_cli.sh"]

# CMD = výchozí argumenty (žádné)
# Když uživatel zadá parametry za 'docker run', nahradí CMD,
# ale ENTRYPOINT zůstává.
CMD []
