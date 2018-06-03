
# SOBRE

O trabalho tem como princípio elaborar uma solução que dado um determinado domínio, verifique se há alguma potencial ameaça. Para essa solução, utilizei ferramentas Open Source. 
Antes de prosseguir com o relatório assume-se que o leitor já tenha conhecimentos prévios em Linux, Bash Script e Bind.
Para facilitar a leitura, trechos de texto que estiverem sob cor cinza são partes que devem ser inseridas dentro da console do seu sistema operacional.
e.g. sudo yum install bind9
O commando acima instala o servidor de DNS bind. Para efeitos de reprodução, o ambiente utilizado neste estudo foi o Ubuntu 17.10 (Minimal isso – 60mb).
http://archive.ubuntu.com/ubuntu/dists/artful/main/installer-amd64/current/images/netboot/mini.iso
Embora o processo possa ser facilmente replicado em outras distribuições, basta devida atenção as versões dos pacotes.

# O PROJETO

O presente trabalho irá discorrer de maneira sucinta e breve os passos para instalação de uma aplicação para análise de domínios e qual sua aplicabilidade nos dias atuais. 
Embora sejam utilizadas bibliotecas escritas em ruby e python, o cerne da aplicação consiste em 3 arquivos escritos em Bash Script. 
Optou-se por esta scripting language pela versatilidade que garante e pela facilidade em trabalhar com strings e arrays. Embora não possua o desempenho de uma linguagem de baixa ou alta abstração como C ou Java, respetivamente, permite que em consoante com as bibliotecas GNU/Linux se concretize resultados satisfatórios.
A curva de aprendizado para executar a aplicação é baixa e o usuário final tem como necessidade apenas a de baixar as dependências, alterar as permissões dos arquivos e alterar nos arquivos o caminho para o Banco de Dados que pode ser MariaDB, MySQL ou mesmo SQL Express Server.
A aplicação como um todo embora funcional está longe de estar pronta para um ambiente de produção. E, caso usada para este fim, deve-se ter em mente isto. 
Em linhas gerais cada um dos scripts segue um fluxo similar a isto:

Em linhas gerais, após input do utilizador, o bash script envia este input ao URL Crazy que por sua vez cria uma lista de possíveis e prováveis domínios, considerando Typos, alteração de TLD’s, misspells, bit flipping, troca de vogais e Homoglifos. Esta lista serve como base para outras ferramentas que vão em suma verificar se o domínio está ou não registrado, a data de registro e qual a localização do servidor DNS autoritativo para aquele domínio. O que estas ferramentas retornam é então processado e redirecionado para o Banco de dados, afim de manter consistência e garantir o estudo para futuras pesquisas.
Em um segundo momento, o Script verifica um determinado PCAP e cruza as informações obtidas pelo PCAP com duas listas de malware, uma gerada pela Alexa (Amazon) que contém domínios verificados e validados, e outra que apresenta domínios propriamente conhecidos por infundir malware ou outra forma de ameaça. Os domínios encontrados dentro do PCAP que coincidam com a lista de malwares são então enviados para um dado servidor DNS criando uma sink zone, onde então qualquer pedido da rede interna para estes domínios será derrubado. Este Script ainda atribui um indicador de quão malicioso pode ser os domínios verificados no PCAP.
A próxima parte mostrará os passos para instalação dos scripts, bem como em detalhes como utilizar-os. 
INSTALAÇÃO DE DEPENDÊNCIAS

Antes de começarmos, precisamos sobretudo instalar as dependências necessárias. Para isso, favor digitar em seu console:
sudo apt update
sudo apt upgrade
sudo apt install unzip wget bind9 bind9utils mysql-server-5.7 git ruby automake autoconf libtool whois geoip-bin geoip-database nmap webkit-image-gtk bc ent dnsmasq
sudo wget http://www.morningstarsecurity.com/downloads/urlcrazy-0.5.tar .gz -d /home
cd /home
sudo tar -xvf urlcrazy-0.5.tar.gz
mysql_secure_installation
Este último comando remove anonymous permissions do banco de dados, tabelas desnecessárias e desabilita o login remoto do usuário root ao banco de dados. Caso queira, pode ser dispensado. Embora seja altamente recomendado rodá-lo.

# BAIXAR SCRIPTS

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
DNS

Para configuração do DNS, utilizei a imagem do Ubuntu 16.04 LTS. Para os passos adiantes, configurei usando as informações a seguir, favor adequar para seu respetivo cenário:
    • Hostname: dns.chostak
    • DNS: ec2-35-176-74-179.eu-west-2.compute.amazonaws.com
    • IPv4 Público: 35.176.74.179
    • DNS Privado: ip-172-31-20-158.eu-west-2.compute.internal
    • IPv4 Privado: 172.31.20.158
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
$TTL    600
@                       1D IN SOA       localhost root (
                                        42              ; serial
                                        3H              ; refresh
                                        15M             ; retry
                                        1W              ; expiry
                                        1D )            ; minimum

                        1D IN NS        @
                        5 IN A          localhost
O script adicionará cada domínio malicioso no arquivo sinkhole.conf, e cada linha redirecionará o tráfego para o arquivo no.redirect que vai apontar diretamente para o localhost.
zone “$file" IN { type master; file "/etc/bind/no.redirect"; };

# EXECUÇÃO

Para execução dos scripts, basta executá-los da maneira convencional:
./scriptDNS.sh VARIAVEL1 VARIAVEL 2
Sendo a VARIAVEL 1 o caminho para o arquivo PCAP, e a VARIAVEL2 como você quer armazenar a busca. Pode-se ainda executar o arquivo sem a informação das VARIAVEIS, neste caso o script lhe solicitara estes dados. Um exemplo, se tivéssemos um arquivo domínios.pcap na mesma raiz do script e quiséssemos salvar a busca como ciberintel, poderíamos invocar o script com:
./scriptDNS.sh domínios.pcap ciberintel
De forma igual pode-se chamar os demais scripts:
./scriptURL.sh VARIAVEL1 VARIAVEL 2
Sendo a VARIAVEL1 a URL a que se deseja buscar informação, e a VARIAVEL2 o nome que deseja salvar a busca. Um aviso ao usuário no entanto é que não use nomes com pontuação na segunda variável, isso deve-se ao fato desta variável ser usada para armazenar no banco de dados e criação de arquivos, e embora seja possível processar o nome antes de executar o script optei por não fazê-lo. Como exemplo, imagina-se que queira buscar o domínio google.com e salvar a busca como teste, bastaria invocar o comando:
./scriptURL.sh google.com teste
Por fim, o último script tem a seguinte condição:
./scriptPIC.sh VARIAVEL1 VARIAVEL2
Sendo que VARIAVEL1 significa o caminho para o arquivo gerado pelo scriptURL.sh, geralmente /nomeDaBuscaAnterior/nomeDoDominioAnterior.txt e a VARIAVEL2 como gostaria de salvar esta busca. 
Imagine que rodaste o arquivo scriptURL.sh da forma anterior:
./scriptURL.sh google.com teste
Dentro de /teste/ haveria um arquivo chamado google.com.txt. Desta forma, poderíamos chamar o segundo script da seguinte forma:
./scriptPIC.sh /teste/google.com.txt fotos
E a nova busca seria gravada dentro de uma pasta chamada fotos.
Com relação ao algoritmo para validar um domínio, efetuou-se uma análise do estudo do Kelvin Tan, que avaliou cerca de 4.074.300 URL’s únicas, onde pode aferir-se que a média para uma URL convencional é de cerca de 34 caracteres. O algoritmo então utiliza a biblioteca ent para gerar o grau de entropia da URL, bem como avalia a dimensão da URL, logo procede para multiplicar o valor da entropia pelo número de caracteres, dividindo o produto por 1000. O que se percebe é que domínios com alta entropia, e muitos caracteres fornecem um produto muito maior que sites convencionais, por tanto, em uma escala de 0 a 100 pode-se dizer que domínios que fiquem entre 0 e 15 são pouco ou nada suspeitos, e a medida que o indicador ultrapassa a casa dos 15, esse domínio deve ser avaliado com maior cautela.
Os scripts fazem uso ainda do MySQL para armazenar os dados, tornando a análise um tanto quanto prática.
https://www.malware-traffic-analysis.net/

# CONCLUSÕES

O projeto embora em fase experimental possibilita que o utilizador faça uma análise do domínio em questão para estreitar ainda mais a segurança da organização. Os próximos passos do projeto são torná-lo um ambiente web para que qualquer pessoa possa utilizá-lo.
Há ainda de se tornar a instalação mais prática criando uma única tarball para extração de todos os arquivos necessários.
Por fim, a utilização deve possibilitar a criação de um sumário executivo de fácil leitura, em .pdf, para que seja dirigido aos gestores da organização.
Percebeu-se que embora de certa maneira incipientes, os scripts realizam o que foram desenvolvidos para fazer, analisar domínio e fornecer informação sobre suas variações. Serve ainda para automatizar as regras de bloqueio em firewall e dns, fazendo com que todos os domínios maliciosos sejam redirecionados para o ip de loopback 127.0.0.1.