#!/bin/bash

# Detectar automaticamente o IP do gateway
IP_FIREWALL_INTERNO=$(ip route | grep default | awk '{print $3}')

if [ -z "$IP_FIREWALL_INTERNO" ]; then
    echo "Erro: Não foi possível detectar o IP do gateway automaticamente"
    exit 1
fi

echo "Gateway detectado: $IP_FIREWALL_INTERNO"

# Atualizar pacotes e instalar Apache e outras dependências
echo "Atualizando pacotes e instalando Apache, iptables e tcpdump..."
sudo apt update
sudo apt install -y apache2 iptables tcpdump

# Obter IP automaticamente para a interface eth0 usando DHCP
echo "Obtendo IP dinâmico para eth0..."
sudo dhclient eth0

# Limpar regras existentes no iptables
echo "Limpando regras do iptables..."
sudo iptables -F
sudo iptables -t nat -F

# Remover a rota padrão existente e configurar a nova rota padrão para o gateway interno
echo "Configurando a rota padrão para o gateway interno..."
sudo ip route del default
sudo ip route add default via $IP_FIREWALL_INTERNO dev eth0

# Permitir tráfego HTTP na porta 80
echo "Permitindo tráfego HTTP na porta 80..."
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP

echo "Configuração do Apache concluída!"
