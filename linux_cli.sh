#! /bin/bash

echo "Shell: $SHELL"
echo ""
echo "Aktuální uživatel: $(whoami)"
echo""
echo "Verze Linuxu: $(cat /etc/os-release)"
echo ""
echo "Enviroment varialble:"
printenv

