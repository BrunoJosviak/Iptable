#!/bin/bash

# Função para obter IP de uma interface
get_interface_ip() {
    local interface=$1
    local ip=$(ip addr show $interface 2>/dev/null | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
    echo $ip
}

# Detectar IPs automaticamente
echo "Detectando IPs..."

# Detectar IP do gateway externo
IP_GATEWAY=$(ip route | grep default | awk '{print $3}')
if [ -z "$IP_GATEWAY" ]; then
    echo "Erro: Não foi possível detectar o IP do gateway externo"
    exit 1
fi

# Detectar IP do firewall na interface interna (eth0)
IP_FIREWALL_INTERNO=$(get_interface_ip eth0)
if [ -z "$IP_FIREWALL_INTERNO" ]; then
    echo "Erro: Não foi possível detectar o IP do firewall na interface interna"
    exit 1
fi

# Detectar IP do Apache na rede interna
# Assumindo que o Apache está na mesma subnet que eth0
IP_APACHE_INTERNO=$(ping -c 1 apache 2>/dev/null | head -n 1 | awk '{print $3}' | tr -d '()')
if [ -z "$IP_APACHE_INTERNO" ]; then
    echo "Aviso: Não foi possível detectar o IP do Apache automaticamente"
    echo "Por favor, insira o IP do Apache manualmente:"
    read IP_APACHE_INTERNO
    if [ -z "$IP_APACHE_INTERNO" ]; then
        echo "Erro: IP do Apache é necessário"
        exit 1
    fi
fi

# Exibir IPs detectados
echo "IPs detectados:"
echo "Gateway Externo: $IP_GATEWAY"
echo "Firewall Interno: $IP_FIREWALL_INTERNO"
echo "Apache Interno: $IP_APACHE_INTERNO"

# Atualizar pacotes e instalar dependências
echo "Atualizando pacotes e instalando dependências..."
sudo apt update
sudo apt install -y iptables tcpdump

# Obter IP automaticamente para a interface eth1 usando DHCP
echo "Obtendo IP dinâmico para eth1..."
sudo dhclient eth1

# Limpar regras existentes no iptables
echo "Limpando regras do iptables..."
sudo iptables -F
sudo iptables -t nat -F

# Habilitar IP forwarding
echo "Habilitando IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1

# Configurar rota padrão para a rede externa
echo "Configurando a rota padrão para o gateway..."
sudo ip route add default via $IP_GATEWAY dev eth1

# Adicionar rota para a rede interna onde o servidor Apache está localizado
echo "Adicionando rota para a rede interna..."
sudo ip route add $IP_APACHE_INTERNO via $IP_FIREWALL_INTERNO dev eth0

# Configurar NAT para redirecionar o tráfego HTTP que chega na interface externa (eth1) para o Apache
echo "Configurando redirecionamento de tráfego HTTP para o Apache..."
sudo iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j DNAT --to-destination $IP_APACHE_INTERNO:80

# Configurar SNAT para que o Apache responda através do firewall
echo "Configurando SNAT para pacotes de resposta do Apache..."
sudo iptables -t nat -A POSTROUTING -o eth0 -d $IP_APACHE_INTERNO -p tcp --dport 80 -j SNAT --to-source $IP_FIREWALL_INTERNO

# Permitir o encaminhamento de pacotes HTTP para o Apache
echo "Permitindo encaminhamento de pacotes HTTP para o Apache..."
sudo iptables -A FORWARD -i eth1 -o eth0 -p tcp --dport 80 -d $IP_APACHE_INTERNO -j ACCEPT

# Bloquear outros pacotes destinados ao Apache
echo "Bloqueando outros pacotes destinados ao Apache..."
sudo iptables -A FORWARD -o eth0 -d $IP_APACHE_INTERNO -j DROP

echo "Configuração do firewall concluída!"
