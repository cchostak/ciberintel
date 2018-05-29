#SOBRE
O trabalho tem como princípio elaborar uma solução que dado um determinado domínio, verifique se há alguma potencial ameaça. Para essa solução, utilizei ferramentas Open Source. 
Antes de prosseguir com o relatório assume-se que o leitor já tenha conhecimentos prévios em Linux, Bash Script e Bind.
Para facilitar a leitura, trechos de texto que estiverem sob cor cinza são partes que devem ser inseridas dentro da console do seu sistema operacional.
e.g. sudo yum install bind9
O commando acima instala o servidor de DNS bind. Para efeitos de reprodução, o ambiente utilizado neste estudo foi o Ubuntu 17.10 (Minimal isso – 60mb).
http://archive.ubuntu.com/ubuntu/dists/artful/main/installer-amd64/current/images/netboot/mini.iso
(MD5: 8006b73636a3df5d4f3aa3fdfa9b02cc, SHA1: 7ff172b06aa07ab4dfa2b97e2ac67c30d0dbfe85)
 
#INSTALAÇÃO DE DEPENDÊNCIAS
Antes de começarmos, precisamos sobretudo instalar as dependências necessárias. Para isso, favor digitar em seu console:
sudo apt update
sudo apt upgrade
sudo apt install unzip wget bind9 bind9utils mysql-server-5.7 git ruby automake autoconf libtool whois geoip-bin geoip-database nmap webkit-image-gtk bc ent
sudo wget http://www.morningstarsecurity.com/downloads/urlcrazy-0.5.tar .gz -d /home
cd /home
sudo tar -xvf urlcrazy-0.5.tar.gz
mysql_secure_installation

#BAIXAR SCRIPTS
Para efetuar o download dos scripts, aceder ao diretório:
https://github.com/cchostak/ciberintel.git
Efetuar o download dos scripts que contém o sufixo .sh. Adicioná-los de preferência a home do seu sistema:
cd /home/
git clone https://github.com/cchostak/ciberintel
cd ciberintel
chmod +x scriptDNS.sh scriptPIC.sh scriptURL.sh
Alterar no script scripURL.sh na linha 35 a localização do arquivo geoIP.dat, e.g.
/home/ciberintel/geo.dat
Alterar no script scripURL.sh na linha 29 a senha para o seu servidor MySQL, e.g.
DB_PASS=umaSenha
Alterar no script scripPIC.sh na linha 29 a senha para o seu servidor MySQL, e.g.
DB_PASS=umaSenha


#DNS
Para configuração do DNS, utilizei a imagem do Ubuntu 16.04 LTS. Para os passos adiantes, configurei usando as informações a seguir, favor adequar para seu respetivo cenário:
Hostname: dns.chostak
DNS: ec2-35-176-74-179.eu-west-2.compute.amazonaws.com
IPv4 Público: 35.176.74.179
DNS Privado: ip-172-31-20-158.eu-west-2.compute.internal
IPv4 Privado: 172.31.20.158
Status firewall: Desabilitado
Após atualizar o sistema com:
apt update
apt upgrade
Instalar e atualizar o servidor DNS com:
apt install bind9 bind9utils
Criar as zones wan e lan, ajustando para sua realidade:
 
___________
vi /etc/bind/named.conf.internal-zones

view "internal" {

        match-clients {
                localhost;
                172.31.20.158/24;
        };


        zone "dns.chostak" {
                type master;
                file "/etc/bind/dns.chostak.lan";
                allow-update { none; };
        };


        zone "158.20.31.172.in-addr.arpa" {
                type master;
                file "/etc/bind/158.20.31.172.db";
                allow-update { none; };
        };
        include "/etc/bind/named.conf.default-zones";
};


___________

vi /etc/bind/named.conf.external-zones

view "external" {
        match-clients { any; };
        allow-query { any; };
        recursion no;
        zone "dns.chostak" {
                type master;
                file "/etc/bind/dns.chostak.wan";
                allow-update { none; };
        };

        zone "179.74.176.35.in-addr.arpa" {
                type master;
                file "/etc/bind/179.74.176.35.db";
                allow-update { none; };
        };
};

___________

vi /etc/bind/dns.chostak.lan

$TTL 86400
@   IN  SOA     dns.chostak. root.dns.chostak. (
        2016042101  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)

        IN  NS      dns.chostak.

        IN  A       172.31.20.158

        IN  MX 10   dns.chostak.

dns     IN  A       172.31.20.158

________

vi /etc/bind/dns.chostak.wan

$TTL 86400
@   IN  SOA     dns.chostak. root.dns.chostak. (
        2016042101  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)

        IN  NS      dns.chostak.

        IN  A       35.176.74.179

        IN  MX 10   dns.chostak.

dns     IN  A       35.176.74.179

__________

vi /etc/bind/158.20.31.172.db

$TTL 86400
@   IN  SOA     dns.chostak. root.dns.chostak. (
        2016042101  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)

        IN  NS      dns.chostak.

        IN  PTR     dns.chostak.
        IN  A       255.255.255.0

30      IN  PTR     dns.chostak.

_________

vi /etc/bind/179.74.176.35.db

$TTL 86400
@   IN  SOA     dns.chostak. root.dns.chostak. (
        2016042101  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)

        IN  NS      dns.chostak.

        IN  PTR     dns.chostak.
        IN  A       255.255.255.248

82      IN  PTR     dns.chostak.


__________

vi /etc/network/interfaces

dns-nameservers 172.31.20.158

__________

vi /etc/resolv.conf

dns-nameservers 172.31.20.158
 

Após a configuração do serviço, no arquivo de configuração do Bind em /etc/bind/named.conf.local, adicionar um arquivo de configuração chamado sinkhole.conf, ex:
include /etc/bind/sinkhole.conf
Crie o arquivo referido usando:
touch /etc/bind/sinkhole.conf
Este arquivo será usado pelo script para enviar os domínios maliciosos. Crie um outro arquivo:
touch /etc/bind/no.redirect
Neste arquivo insira a seguinte informação:
$TTL    600
@                       1D IN SOA       localhost root (
                                        42              ; serial
                                        3H              ; refresh
                                        15M             ; retry
                                        1W              ; expiry
                                        1D )            ; minimum

                        1D IN NS        @
                        5 IN A          localhost
O script adicionará cada domínio malicioso no arquivo sinkhole.conf, e cada linha redirecionará o tráfego para o arquivo no.redirect que vai apontar diretamente para o localhost.
zone “$file" IN { type master; file "/etc/bind/no.redirect"; };
