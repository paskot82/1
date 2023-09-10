#!/bin/bash
# отключение проверки оболочки=SC1091,SC2164,SC2034,SC1072, SC1073,SC1009

# Безопасный установщик сервера OpenVPN для Debian, Ubuntu, CentOS, Amazon Linux 2, Fedora, Oracle Linux 8, Arch Linux, Rocky Linux и AlmaLinux.
# El/Star



if [ $# -ne 0 ]; then 
AUTO_INSTALL="y"
AUTO_EXIT="y"
#clientA=$1
fi





#if [ "$2" ];then
echo
#fi

function isRoot() {
	if [ "$EUID" -ne 0 ]; then
		return 1
	fi
}

function tunAvailable() {
	if [ ! -e /dev/net/tun ]; then
		return 1
	fi
}

function checkOS() {
	if [[ -e /etc/debian_version ]]; then
		OS="debian"
		source /etc/os-release

		if [[ $ID == "debian" || $ID == "raspbian" ]]; then
			if [[ $VERSION_ID -lt 9 && ! $AUTO_INSTALL = "y" ]]; then
				echo "⚠️ Ваша версия Debian не поддерживается."
				echo ""
				echo "Однако, если вы используете Debian >= 9 или нестабильный / тестируемый, вы можете продолжить на свой страх и риск."
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "Продолжать? [y/n]: " -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		elif [[ $ID == "ubuntu" ]]; then
			OS="ubuntu"
			MAJOR_UBUNTU_VERSION=$(echo "$VERSION_ID" | cut -d '.' -f1)
			if [[ $MAJOR_UBUNTU_VERSION -lt 16 && ! $AUTO_INSTALL = "y" ]]; then
				echo "⚠️ Ваша версия Ubuntu не поддерживается."
				echo ""
				echo "Однако, если вы используете Ubuntu >= 16.04 или бета-версию, вы можете продолжить на свой страх и риск."
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "Продолжать? [y/n]: " -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		fi
	elif [[ -e /etc/system-release ]]; then
		source /etc/os-release
		if [[ $ID == "fedora" || $ID_LIKE == "fedora" ]]; then
			OS="fedora"
		fi
		if [[ $ID == "centos" || $ID == "rocky" || $ID == "almalinux" ]]; then
			OS="centos"
			if [[ ! $VERSION_ID =~ (7|8) ]]; then
				echo "⚠️ Ваша версия CentOS не поддерживается."
				echo ""
				echo "Скрипт поддерживает только CentOS 7 и CentOS 8."
				echo ""
				exit 1
			fi
		fi
		if [[ $ID == "ol" ]]; then
			OS="oracle"
			if [[ ! $VERSION_ID =~ (8) ]]; then
				echo "Ваша версия Oracle Linux не поддерживается."
				echo ""
				echo "Скрипт поддерживает только Oracle Linux 8."
				exit 1
			fi
		fi
		if [[ $ID == "amzn" ]]; then
			OS="amzn"
			if [[ $VERSION_ID != "2" ]]; then
				echo "⚠️ Ваша версия Amazon Linux не поддерживается."
				echo ""
				echo "Скрипт поддерживает только Amazon Linux 2."
				echo ""
				exit 1
			fi
		fi
	elif [[ -e /etc/arch-release ]]; then
		OS=arch
	else
		echo "Похоже, вы не запускаете этот установщик в системах Debian, Ubuntu, Fedora, CentOS, Amazon Linux 2, Oracle Linux 8 или Arch Linux"
		exit 1
	fi
}

function initialCheck() {
	if ! isRoot; then
		echo "Извините, вам нужно запустить скрипт от имени root"
		exit 1
	fi
	if ! tunAvailable; then
		echo "TUN недоступен"
		exit 1
	fi
	checkOS
}

function installUnbound() {
	# Если Unbound не установлен, установите его
	if [[ ! -e /etc/unbound/unbound.conf ]]; then

		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get install -y unbound

			# Конфигурация
			echo 'interface: 10.8.0.1
access-control: 10.8.0.1/24 allow
hide-identity: yes
hide-version: yes
use-caps-for-id: yes
prefetch: yes' >>/etc/unbound/unbound.conf

		elif [[ $OS =~ (centos|amzn|oracle) ]]; then
			yum install -y unbound

			# Конфигурация
			sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
			sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
			sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
			sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
			sed -i 's|use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

		elif [[ $OS == "fedora" ]]; then
			dnf install -y unbound

			# Конфигурация
			sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
			sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
			sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
			sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
			sed -i 's|# use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

		elif [[ $OS == "arch" ]]; then
			pacman -Syu --noconfirm unbound

			# Получить список корневых серверов
			curl -o /etc/unbound/root.hints https://www.internic.net/domain/named.cache

			if [[ ! -f /etc/unbound/unbound.conf.old ]]; then
				mv /etc/unbound/unbound.conf /etc/unbound/unbound.conf.old
			fi

			echo 'server:
	use-syslog: yes
	do-daemonize: no
	username: "unbound"
	directory: "/etc/unbound"
	trust-anchor-file: trusted-key.key
	root-hints: root.hints
	interface: 10.8.0.1
	access-control: 10.8.0.1/24 allow
	port: 53
	num-threads: 2
	use-caps-for-id: yes
	harden-glue: yes
	hide-identity: yes
	hide-version: yes
	qname-minimisation: yes
	prefetch: yes' >/etc/unbound/unbound.conf
		fi

		# IPv6 DNS для всех ОС
		if [[ $IPV6_SUPPORT == 'y' ]]; then
			echo 'interface: fd42:42:42:42::1
access-control: fd42:42:42:42::/112 allow' >>/etc/unbound/unbound.conf
		fi

		if [[ ! $OS =~ (fedora|centos|amzn|oracle) ]]; then
			# DNS Rebinding fix
			echo "private-address: 10.0.0.0/8
private-address: fd42:42:42:42::/112
private-address: 172.16.0.0/12
private-address: 192.168.0.0/16
private-address: 169.254.0.0/16
private-address: fd00::/8
private-address: fe80::/10
private-address: 127.0.0.0/8
private-address: ::ffff:0:0/96" >>/etc/unbound/unbound.conf
		fi
	else # Несвязанный уже установлен
		echo 'include: /etc/unbound/openvpn.conf' >>/etc/unbound/unbound.conf

		# Добавить несвязанный "сервер" для подсети OpenVPN
		echo 'server:
interface: 10.8.0.1
access-control: 10.8.0.1/24 allow
hide-identity: yes
hide-version: yes
use-caps-for-id: yes
prefetch: yes
private-address: 10.0.0.0/8
private-address: fd42:42:42:42::/112
private-address: 172.16.0.0/12
private-address: 192.168.0.0/16
private-address: 169.254.0.0/16
private-address: fd00::/8
private-address: fe80::/10
private-address: 127.0.0.0/8
private-address: ::ffff:0:0/96' >/etc/unbound/openvpn.conf
		if [[ $IPV6_SUPPORT == 'y' ]]; then
			echo 'interface: fd42:42:42:42::1
access-control: fd42:42:42:42::/112 allow' >>/etc/unbound/openvpn.conf
		fi
	fi

	systemctl enable unbound
	systemctl restart unbound
}

function installQuestions() {
	echo "Добро пожаловать в программу установки OpenVPN!"
	echo "Репозиторий git доступен по адресу: https://github.com/angristan/openvpn-install"
	echo ""

	echo "Мне нужно задать вам несколько вопросов, прежде чем приступить к настройке."
	echo "Вы можете оставить параметры по умолчанию и просто нажать enter, если они вас устраивают."
	echo ""
	echo "Мне нужно знать IPv4-адрес сетевого интерфейса, который вы хотите, чтобы OpenVPN прослушивал."
	echo "Если ваш сервер не находится за NAT, это должен быть ваш общедоступный IPv4-адрес."

	# Определение общедоступного IPv4-адреса и предварительное заполнение для пользователя
	IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)

	if [[ -z $IP ]]; then
		# Detect public IPv6 address
		IP=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)
	fi
	APPROVE_IP=${APPROVE_IP:-n}
	if [[ $APPROVE_IP =~ n ]]; then
		read -rp "IP address: " -e -i "$IP" IP
	fi
	# If Если $IP - это частный IP-адрес, сервер должен находиться за NAT
	if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
		echo ""
		echo "Похоже, этот сервер находится за NAT. Каков его общедоступный IPv4-адрес или имя хоста?"
		echo "Нам это нужно для того, чтобы клиенты могли подключаться к серверу."

		PUBLICIP=$(curl -s https://api.ipify.org)
		until [[ $ENDPOINT != "" ]]; do
			read -rp "Общедоступный IPv4-адрес или имя хоста: " -e -i "$PUBLICIP" ENDPOINT
		done
	fi

	echo ""
	echo "Проверка подключения по протоколу IPv6..."
	echo ""
	# "доступность "ping6" и "ping -6" варьируется в зависимости от дистрибутива
	if type ping6 >/dev/null 2>&1; then
		PING6="ping6 -c3 ipv6.google.com > /dev/null 2>&1"
	else
		PING6="ping -6 -c3 ipv6.google.com > /dev/null 2>&1"
	fi
	if eval "$PING6"; then
		echo "Похоже, что у вашего хоста есть подключение по протоколу IPv6."
		SUGGESTION="y"
	else
		echo "Похоже, что у вашего хоста нет подключения по протоколу IPv6."
		SUGGESTION="n"
	fi
	echo ""
	# Спросите пользователя, хочет ли он включить IPv6 независимо от его доступности.
	until [[ $IPV6_SUPPORT =~ (y|n) ]]; do
		read -rp "Вы хотите включить поддержку IPv6 (NAT)? [y/n]: " -e -i $SUGGESTION IPV6_SUPPORT
	done
	echo ""
	echo "Какой порт вы хотите, чтобы OpenVPN прослушивал?"
	echo "   1) По умолчанию: 443"
	echo "   2) индивидуальный заказ [1194]"
	echo "   3) Случайный Порт: [49152-65535]"
	until [[ $PORT_CHOICE =~ ^[1-3]$ ]]; do
		read -rp "Выбор порта [1-3]: " -e -i 1 PORT_CHOICE
	done
	case $PORT_CHOICE in
	1)
		PORT="443"
		;;
	2)
		until [[ $PORT =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; do
			read -rp "Пользовательский порт [1-65535]: " -e -i 1194 PORT
		done
		;;
	3)
		# Generate random number within private ports range
		PORT=$(shuf -i49152-65535 -n1)
		echo "Случайный Порт: $PORT"
		;;
	esac
	echo ""
	echo "Какой протокол вы хотите, чтобы OpenVPN использовал?"
	echo "UDP работает быстрее. Если он не доступен, вы не должны использовать TCP."
	echo "   1) UDP"
	echo "   2) TCP"
	until [[ $PROTOCOL_CHOICE =~ ^[1-2]$ ]]; do
		read -rp "Протокол [1-2]: " -e -i 1 PROTOCOL_CHOICE
	done
	case $PROTOCOL_CHOICE in
	1)
		PROTOCOL="udp"
		;;
	2)
		PROTOCOL="tcp"
		;;
	esac
	echo ""
	echo "Какие преобразователи DNS вы хотите использовать с VPN?"
	echo "   1) Текущие системные преобразователи (из /etc/resolv.conf)"
	echo "   2) Автономный распознаватель DNS (несвязанный)"
	echo "   3) Cloudflare (Anycast: по всему миру)"
	echo "   4) Quad9 (Anycast: по всему миру)"
	echo "   5) Quad9 uncensored (Anycast: по всему миру)"
	echo "   6) FDN (France)"
	echo "   7) DNS.WATCH (Germany)"
	echo "   8) OpenDNS (Anycast: по всему миру)"
	echo "   9) Google (Anycast: по всему миру)"
	echo "   10) Yandex Basic (Russia)"
	echo "   11) AdGuard DNS (Anycast: по всему миру)"
	echo "   12) NextDNS (Anycast: по всему миру)"
	echo "   13) индивидуальный заказ"
	until [[ $DNS =~ ^[0-9]+$ ]] && [ "$DNS" -ge 1 ] && [ "$DNS" -le 13 ]; do
		read -rp "DNS [1-12]: " -e -i 11 DNS
		if [[ $DNS == 2 ]] && [[ -e /etc/unbound/unbound.conf ]]; then
			echo ""
			echo "Несвязанный уже установлен."
			echo "Вы можете разрешить скрипту настраивать его, чтобы использовать его из ваших клиентов OpenVPN"
			echo "Мы просто добавим второй сервер в /etc/unbound/unbound.conf для подсети OpenVPN."
			echo "В текущую конфигурацию не вносится никаких изменений."
			echo ""

			until [[ $CONTINUE =~ (y|n) ]]; do
				read -rp "Применить изменения конфигурации к несвязанному? [y/n]: " -e CONTINUE
			done
			if [[ $CONTINUE == "n" ]]; then
				# Разрыв цикла и очистка
				unset DNS
				unset CONTINUE
			fi
		elif [[ $DNS == "13" ]]; then
			until [[ $DNS1 =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
				read -rp "Первичный DNS: " -e DNS1
			done
			until [[ $DNS2 =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
				read -rp "Вторичный DNS (необязательно): " -e DNS2
				if [[ $DNS2 == "" ]]; then
					break
				fi
			done
		fi
	done
	echo ""
	echo "Вы хотите использовать сжатие? Это не рекомендуется, так как атака VORACLE использует его."
	until [[ $COMPRESSION_ENABLED =~ (y|n) ]]; do
		read -rp"Включить сжатие? [y/n]: " -e -i y COMPRESSION_ENABLED
	done
	if [[ $COMPRESSION_ENABLED == "y" ]]; then
		echo "Выберите, какой алгоритм сжатия вы хотите использовать: (они упорядочены по эффективности)"
		echo "   1) LZ4-v2"
		echo "   2) LZ4"
		echo "   3) LZ0"
		until [[ $COMPRESSION_CHOICE =~ ^[1-3]$ ]]; do
			read -rp"Алгоритм сжатия [1-3]: " -e -i 1 COMPRESSION_CHOICE
		done
		case $COMPRESSION_CHOICE in
		1)
			COMPRESSION_ALG="lz4-v2"
			;;
		2)
			COMPRESSION_ALG="lz4"
			;;
		3)
			COMPRESSION_ALG="lzo"
			;;
		esac
	fi
	echo ""
	echo "Вы хотите настроить параметры шифрования?"
	echo "Если вы не знаете, что делаете, вам следует придерживаться параметров по умолчанию, предоставляемых скриптом."
	echo "Обратите внимание, что что бы вы ни выбрали, все варианты, представленные в скрипте, безопасны."
	echo " (В отличие от настроек OpenVPN по умолчанию)"
	echo "See https://github.com/angristan/openvpn-install#security-and-encryption to learn more."
	echo ""
	until [[ $CUSTOMIZE_ENC =~ (y|n) ]]; do
		read -rp "Customize encryption settings? [y/n]: " -e -i y CUSTOMIZE_ENC
	done
	if [[ $CUSTOMIZE_ENC == "n" ]]; then
		# Используйте стандартные, разумные и быстрые параметры
		CIPHER="AES-128-GCM"
		CERT_TYPE="1" # ECDSA
		CERT_CURVE="prime256v1"
		CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
		DH_TYPE="1" # ECDH
		DH_CURVE="prime256v1"
		HMAC_ALG="SHA256"
		TLS_SIG="1" # tls-crypt
	else
		echo ""
		echo "Выберите, какой шифр вы хотите использовать для канала передачи данных:"
		echo "   1) AES-128-GCM (рекомендуемый)"
		echo "   2) AES-192-GCM"
		echo "   3) AES-256-GCM"
		echo "   4) AES-128-CBC"
		echo "   5) AES-192-CBC"
		echo "   6) AES-256-CBC"
		until [[ $CIPHER_CHOICE =~ ^[1-6]$ ]]; do
			read -rp "Cipher [1-6]: " -e -i 1 CIPHER_CHOICE
		done
		case $CIPHER_CHOICE in
		1)
			CIPHER="AES-128-GCM"
			;;
		2)
			CIPHER="AES-192-GCM"
			;;
		3)
			CIPHER="AES-256-GCM"
			;;
		4)
			CIPHER="AES-128-CBC"
			;;
		5)
			CIPHER="AES-192-CBC"
			;;
		6)
			CIPHER="AES-256-CBC"
			;;
		esac
		echo ""
		echo "Выберите, какой тип сертификата вы хотите использовать:"
		echo "   1) ECDSA (рекомендуемый)"
		echo "   2) RSA"
		until [[ $CERT_TYPE =~ ^[1-2]$ ]]; do
			read -rp"Тип ключа сертификата [1-2]: " -e -i 1 CERT_TYPE
		done
		case $CERT_TYPE in
		1)
			echo ""
			echo "Выберите, какую кривую вы хотите использовать для ключа сертификата:"
			echo "   1) prime256v1 (рекомендуемый)"
			echo "   2) secp384r1"
			echo "   3) secp521r1"
			until [[ $CERT_CURVE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp"Curve [1-3]: " -e -i 1 CERT_CURVE_CHOICE
			done
			case $CERT_CURVE_CHOICE in
			1)
				CERT_CURVE="prime256v1"
				;;
			2)
				CERT_CURVE="secp384r1"
				;;
			3)
				CERT_CURVE="secp521r1"
				;;
			esac
			;;
		2)
			echo ""
			echo "Выберите, какой размер вы хотите использовать для ключа RSA сертификата:"
			echo "   1) 2048 bits (рекомендуемый)"
			echo "   2) 3072 bits"
			echo "   3) 4096 bits"
			until [[ $RSA_KEY_SIZE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "RSA key size [1-3]: " -e -i 1 RSA_KEY_SIZE_CHOICE
			done
			case $RSA_KEY_SIZE_CHOICE in
			1)
				RSA_KEY_SIZE="2048"
				;;
			2)
				RSA_KEY_SIZE="3072"
				;;
			3)
				RSA_KEY_SIZE="4096"
				;;
			esac
			;;
		esac
		echo ""
		echo "Выберите, какой шифр вы хотите использовать для канала управления:"
		case $CERT_TYPE in
		1)
			echo "   1) ECDHE-ECDSA-AES-128-GCM-SHA256 (рекомендуемый)"
			echo "   2) ECDHE-ECDSA-AES-256-GCM-SHA384"
			until [[ $CC_CIPHER_CHOICE =~ ^[1-2]$ ]]; do
				read -rp"Шифр канала управления [1-2]: " -e -i 1 CC_CIPHER_CHOICE
			done
			case $CC_CIPHER_CHOICE in
			1)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
				;;
			2)
				CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384"
				;;
			esac
			;;
		2)
			echo "   1) ECDHE-RSA-AES-128-GCM-SHA256 (рекомендуемый)"
			echo "   2) ECDHE-RSA-AES-256-GCM-SHA384"
			until [[ $CC_CIPHER_CHOICE =~ ^[1-2]$ ]]; do
				read -rp"Шифр канала управления [1-2]: " -e -i 1 CC_CIPHER_CHOICE
			done
			case $CC_CIPHER_CHOICE in
			1)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256"
				;;
			2)
				CC_CIPHER="TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384"
				;;
			esac
			;;
		esac
		echo ""
		echo "Выберите, какой тип ключа Диффи-Хеллмана вы хотите использовать:"
		echo "   1) ECDH (рекомендуемый)"
		echo "   2) DH"
		until [[ $DH_TYPE =~ [1-2] ]]; do
			read -rp"DH key type [1-2]: " -e -i 1 DH_TYPE
		done
		case $DH_TYPE in
		1)
			echo ""
			echo "Выберите, какую кривую вы хотите использовать для ключа ECDH:"
			echo "   1) prime256v1 (рекомендуемый)"
			echo "   2) secp384r1"
			echo "   3) secp521r1"
			while [[ $DH_CURVE_CHOICE != "1" && $DH_CURVE_CHOICE != "2" && $DH_CURVE_CHOICE != "3" ]]; do
				read -rp"Кривая [1-3]: " -e -i 1 DH_CURVE_CHOICE
			done
			case $DH_CURVE_CHOICE in
			1)
				DH_CURVE="prime256v1"
				;;
			2)
				DH_CURVE="secp384r1"
				;;
			3)
				DH_CURVE="secp521r1"
				;;
			esac
			;;
		2)
			echo ""
			echo "Выберите, какой размер ключа Диффи-Хеллмана вы хотите использовать:"
			echo "   1) 2048 bits (рекомендуемый)"
			echo "   2) 3072 bits"
			echo "   3) 4096 bits"
			until [[ $DH_KEY_SIZE_CHOICE =~ ^[1-3]$ ]]; do
				read -rp "DH key size [1-3]: " -e -i 1 DH_KEY_SIZE_CHOICE
			done
			case $DH_KEY_SIZE_CHOICE in
			1)
				DH_KEY_SIZE="2048"
				;;
			2)
				DH_KEY_SIZE="3072"
				;;
			3)
				DH_KEY_SIZE="4096"
				;;
			esac
			;;
		esac
		echo ""
		# Параметры "auth" ведут себя по-разному с шифрами AEAD
		if [[ $CIPHER =~ CBC$ ]]; then
			echo "Алгоритм дайджеста проверяет подлинность пакетов канала передачи данных и пакетов tls-аутентификации из канала управления."
		elif [[ $CIPHER =~ GCM$ ]]; then
			echo "Алгоритм дайджеста проверяет подлинность пакетов tls-auth из канала управления."
		fi
		echo "Какой алгоритм дайджеста вы хотите использовать для HMAC?"
		echo "   1) SHA-256 (рекомендуемый)"
		echo "   2) SHA-384"
		echo "   3) SHA-512"
		until [[ $HMAC_ALG_CHOICE =~ ^[1-3]$ ]]; do
			read -rp "Алгоритм дайджеста [1-3]: " -e -i 1 HMAC_ALG_CHOICE
		done
		case $HMAC_ALG_CHOICE in
		1)
			HMAC_ALG="SHA256"
			;;
		2)
			HMAC_ALG="SHA384"
			;;
		3)
			HMAC_ALG="SHA512"
			;;
		esac
		echo ""
		echo "Вы можете добавить дополнительный уровень безопасности к каналу управления с помощью tls-auth и tls-crypt"
		echo "tls-auth проверяет подлинность пакетов, в то время как tls-crypt проверяет подлинность и шифрует их."
		echo "   1) tls-crypt (рекомендуемый)"
		echo "   2) tls-auth"
		until [[ $TLS_SIG =~ [1-2] ]]; do
			read -rp "Канал управления дополнительный защитный механизм [1-2]: " -e -i 1 TLS_SIG
		done
	fi
	echo ""
	echo "Ладно, это было все, что мне было нужно. Мы готовы настроить ваш сервер OpenVPN прямо сейчас."
	echo "Вы сможете создать клиент в конце установки."
	APPROVE_INSTALL=${APPROVE_INSTALL:-n}
	if [[ $APPROVE_INSTALL =~ n ]]; then
		read -n1 -r -p "Нажмите любую клавишу, чтобы продолжить..."
	fi
}

function installOpenVPN() {
	if [[ $AUTO_INSTALL == "y" ]]; then
		# Установите параметры по умолчанию, чтобы не было задано никаких вопросов.
		APPROVE_INSTALL=${APPROVE_INSTALL:-y}
		APPROVE_IP=${APPROVE_IP:-y}
		IPV6_SUPPORT=${IPV6_SUPPORT:-n}
		PORT_CHOICE=${PORT_CHOICE:-1}
		PROTOCOL_CHOICE=${PROTOCOL_CHOICE:-1}
		DNS=${DNS:-1}
		COMPRESSION_ENABLED=${COMPRESSION_ENABLED:-n}
		CUSTOMIZE_ENC=${CUSTOMIZE_ENC:-n}
#		CLIENT=${CLIENT:-client}
#		CLIENT=$clientA
		PASS=${PASS:-1}
		CONTINUE=${CONTINUE:-y}

		# За NAT мы по умолчанию будем использовать общедоступный IPv4 / IPv6.
		if [[ $IPV6_SUPPORT == "y" ]]; then
			PUBLIC_IP=$(curl --retry 5 --retry-connrefused https://ifconfig.io)
#			PUBLIC_IP=$(wget -qO- eth0.me)
		else
			PUBLIC_IP=$(curl --retry 5 --retry-connrefused -4 https://ifconfig.io)
#			PUBLIC_IP=$(wget -qO- eth0.me)
		fi
		ENDPOINT=${ENDPOINT:-$PUBLIC_IP}
	fi

	# Сначала запустите вопросы установки и задайте другие переменные, если выполняется автоматическая установка
	installQuestions

	# Получить "общедоступный" интерфейс из маршрута по умолчанию
	NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
	if [[ -z $NIC ]] && [[ $IPV6_SUPPORT == 'y' ]]; then
		NIC=$(ip -6 route show default | sed -ne 's/^default .* dev \([^ ]*\) .*$/\1/p')
	fi

	# $Сетевой адаптер не может быть пустым для скрипта rm-openvpn-rules.sh
	if [[ -z $NIC ]]; then
		echo
		echo "Не удается обнаружить общедоступный интерфейс."
		echo "This needs for setup MASQUERADE."
		until [[ $CONTINUE =~ (y|n) ]]; do
			read -rp "Продолжать? [y/n]: " -e CONTINUE
		done
		if [[ $CONTINUE == "n" ]]; then
			exit 1
		fi
	fi

	# Если OpenVPN еще не установлен, установите его. Этот сценарий более или менее
	# идемпотентен при нескольких запусках, но будет устанавливать OpenVPN только из восходящего потока
	# в первый раз.
	if [[ ! -e /etc/openvpn/server.conf ]]; then
		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get update
			apt-get -y install ca-certificates gnupg
			# Мы добавляем репозиторий OpenVPN, чтобы получить последнюю версию.
			if [[ $VERSION_ID == "16.04" ]]; then
				echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" >/etc/apt/sources.list.d/openvpn.list
				wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
				apt-get update
			fi
			# Ubuntu > 16.04 и Debian > 8 имеют OpenVPN >= 2.4 без необходимости в стороннем репозитории.
			apt-get install -y openvpn iptables openssl wget ca-certificates curl jq
		elif [[ $OS == 'centos' ]]; then
			yum install -y epel-release
			yum install -y openvpn iptables openssl wget ca-certificates curl jq tar 'policycoreutils-python*'
		elif [[ $OS == 'oracle' ]]; then
			yum install -y oracle-epel-release-el8
			yum-config-manager --enable ol8_developer_EPEL
			yum install -y openvpn iptables openssl wget ca-certificates curl tar policycoreutils-python-utils jq
		elif [[ $OS == 'amzn' ]]; then
			amazon-linux-extras install -y epel
			yum install -y openvpn iptables openssl wget ca-certificates curl jq
		elif [[ $OS == 'fedora' ]]; then
			dnf install -y openvpn iptables openssl wget ca-certificates curl policycoreutils-python-utils jq
		elif [[ $OS == 'arch' ]]; then
			# Установите необходимые зависимости и обновите систему
			pacman --needed --noconfirm -Syu openvpn iptables openssl wget ca-certificates curl jq
		fi
		# Старая версия easy-rsa была доступна по умолчанию в некоторых пакетах openvpn
		if [[ -d /etc/openvpn/easy-rsa/ ]]; then
			rm -rf /etc/openvpn/easy-rsa/
		fi
	fi

	# Узнайте, использует ли машина nogroup или nobody для группы без разрешений
	if grep -qs "^nogroup:" /etc/group; then
		NOGROUP=nogroup
	else
		NOGROUP=nobody
	fi

	# Установите последнюю версию easy-rsa из исходного кода, если она еще не установлена.
	if [[ ! -d /etc/openvpn/easy-rsa/ ]]; then
		local version="3.0.7"
		wget -O ~/easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${version}/EasyRSA-${version}.tgz
		mkdir -p /etc/openvpn/easy-rsa
		tar xzf ~/easy-rsa.tgz --strip-components=1 --directory /etc/openvpn/easy-rsa
		rm -f ~/easy-rsa.tgz

		cd /etc/openvpn/easy-rsa/ || return
		case $CERT_TYPE in
		1)
			echo "set_var EASYRSA_ALGO ec" >vars
			echo "set_var EASYRSA_CURVE $CERT_CURVE" >>vars
			;;
		2)
			echo "set_var EASYRSA_KEY_SIZE $RSA_KEY_SIZE" >vars
			;;
		esac

		# Сгенерируйте случайный буквенно-цифровой идентификатор из 16 символов для CN и одного для имени сервера
		SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
		echo "$SERVER_CN" >SERVER_CN_GENERATED
		SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
		echo "$SERVER_NAME" >SERVER_NAME_GENERATED

		echo "set_var EASYRSA_REQ_CN $SERVER_CN" >>vars

		# Создайте PKI, настройте центр сертификации, параметры DH и сертификат сервера
		./easyrsa init-pki
		./easyrsa --batch build-ca nopass

		if [[ $DH_TYPE == "2" ]]; then
			# Ключи ECDH генерируются "на лету", поэтому нам не нужно генерировать их заранее
			openssl dhparam -out dh.pem $DH_KEY_SIZE
		fi

		./easyrsa build-server-full "$SERVER_NAME" nopass
		EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl

		case $TLS_SIG in
		1)
			# Сгенерировать ключ tls-crypt
			openvpn --genkey --secret /etc/openvpn/tls-crypt.key
			;;
		2)
			# Сгенерировать ключ tls-аутентификации
			openvpn --genkey --secret /etc/openvpn/tls-auth.key
			;;
		esac
	else
		# Если easy-rsa уже установлен, введите сгенерированное ИМЯ_СЕРВЕРА
		# для клиентских конфигураций
		cd /etc/openvpn/easy-rsa/ || return
		SERVER_NAME=$(cat SERVER_NAME_GENERATED)
	fi

	# Переместите все сгенерированные файлы
	cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn
	if [[ $DH_TYPE == "2" ]]; then
		cp dh.pem /etc/openvpn
	fi

	# Сделать список отзыва сертификата доступным для чтения для некорневых пользователей
	chmod 644 /etc/openvpn/crl.pem

	# Создать server.conf
	echo "port $PORT" >/etc/openvpn/server.conf
	if [[ $IPV6_SUPPORT == 'n' ]]; then
		echo "proto $PROTOCOL" >>/etc/openvpn/server.conf
	elif [[ $IPV6_SUPPORT == 'y' ]]; then
		echo "proto ${PROTOCOL}6" >>/etc/openvpn/server.conf
	fi

	echo "dev tun
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" >>/etc/openvpn/server.conf

	# Распознаватели DNS
	case $DNS in
	1) # Current system resolvers
		# Locate the proper resolv.conf
		# Needed for systems running systemd-resolved
		if grep -q "127.0.0.53" "/etc/resolv.conf"; then
			RESOLVCONF='/run/systemd/resolve/resolv.conf'
		else
			RESOLVCONF='/etc/resolv.conf'
		fi
		# Obtain the resolvers from resolv.conf and use them for OpenVPN
		sed -ne 's/^nameserver[[:space:]]\+\([^[:space:]]\+\).*$/\1/p' $RESOLVCONF | while read -r line; do
			# Copy, if it's a IPv4 |or| if IPv6 is enabled, IPv4/IPv6 does not matter
			if [[ $line =~ ^[0-9.]*$ ]] || [[ $IPV6_SUPPORT == 'y' ]]; then
				echo "push \"dhcp-option DNS $line\"" >>/etc/openvpn/server.conf
			fi
		done
		;;
	2) # Self-hosted DNS resolver (Unbound)
		echo 'push "dhcp-option DNS 10.8.0.1"' >>/etc/openvpn/server.conf
		if [[ $IPV6_SUPPORT == 'y' ]]; then
			echo 'push "dhcp-option DNS fd42:42:42:42::1"' >>/etc/openvpn/server.conf
		fi
		;;
	3) # Cloudflare
		echo 'push "dhcp-option DNS 1.0.0.1"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 1.1.1.1"' >>/etc/openvpn/server.conf
		;;
	4) # Quad9
		echo 'push "dhcp-option DNS 9.9.9.9"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 149.112.112.112"' >>/etc/openvpn/server.conf
		;;
	5) # Quad9 uncensored
		echo 'push "dhcp-option DNS 9.9.9.10"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 149.112.112.10"' >>/etc/openvpn/server.conf
		;;
	6) # FDN
		echo 'push "dhcp-option DNS 80.67.169.40"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 80.67.169.12"' >>/etc/openvpn/server.conf
		;;
	7) # DNS.WATCH
		echo 'push "dhcp-option DNS 84.200.69.80"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 84.200.70.40"' >>/etc/openvpn/server.conf
		;;
	8) # OpenDNS
		echo 'push "dhcp-option DNS 208.67.222.222"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 208.67.220.220"' >>/etc/openvpn/server.conf
		;;
	9) # Google
		echo 'push "dhcp-option DNS 8.8.8.8"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 8.8.4.4"' >>/etc/openvpn/server.conf
		;;
	10) # Yandex Basic
		echo 'push "dhcp-option DNS 77.88.8.8"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 77.88.8.1"' >>/etc/openvpn/server.conf
		;;
	11) # AdGuard DNS
		echo 'push "dhcp-option DNS 94.140.14.14"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 94.140.15.15"' >>/etc/openvpn/server.conf
		;;
	12) # NextDNS
		echo 'push "dhcp-option DNS 45.90.28.167"' >>/etc/openvpn/server.conf
		echo 'push "dhcp-option DNS 45.90.30.167"' >>/etc/openvpn/server.conf
		;;
	13) # Custom DNS
		echo "push \"dhcp-option DNS $DNS1\"" >>/etc/openvpn/server.conf
		if [[ $DNS2 != "" ]]; then
			echo "push \"dhcp-option DNS $DNS2\"" >>/etc/openvpn/server.conf
		fi
		;;
	esac
	echo 'push "redirect-gateway def1 bypass-dhcp"' >>/etc/openvpn/server.conf

	# Настройки сети IPv6, если это необходимо
	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo 'server-ipv6 fd42:42:42:42::/112
tun-ipv6
push tun-ipv6
push "route-ipv6 2000::/3"
push "redirect-gateway ipv6"' >>/etc/openvpn/server.conf
	fi

	if [[ $COMPRESSION_ENABLED == "y" ]]; then
		echo "compress $COMPRESSION_ALG" >>/etc/openvpn/server.conf
	fi

	if [[ $DH_TYPE == "1" ]]; then
		echo "dh none" >>/etc/openvpn/server.conf
		echo "ecdh-curve $DH_CURVE" >>/etc/openvpn/server.conf
	elif [[ $DH_TYPE == "2" ]]; then
		echo "dh dh.pem" >>/etc/openvpn/server.conf
	fi

	case $TLS_SIG in
	1)
		echo "tls-crypt tls-crypt.key" >>/etc/openvpn/server.conf
		;;
	2)
		echo "tls-auth tls-auth.key 0" >>/etc/openvpn/server.conf
		;;
	esac

	echo "crl-verify crl.pem
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
auth $HMAC_ALG
cipher $CIPHER
ncp-ciphers $CIPHER
tls-server
tls-version-min 1.2
tls-cipher $CC_CIPHER
client-config-dir /etc/openvpn/ccd
status /var/log/openvpn/status.log
verb 3" >>/etc/openvpn/server.conf

	# Создать клиент-config-dir dir
	mkdir -p /etc/openvpn/ccd
	# Создать каталог журнала
	mkdir -p /var/log/openvpn

	# Включить маршрутизацию
	echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-openvpn.conf
	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo 'net.ipv6.conf.all.forwarding=1' >>/etc/sysctl.d/99-openvpn.conf
	fi
	# Применять правила sysctl
	sysctl --system

	# Если SELinux включен и был выбран пользовательский порт, нам нужно это
	if hash sestatus 2>/dev/null; then
		if sestatus | grep "Current mode" | grep -qs "enforcing"; then
			if [[ $PORT != '1194' ]]; then
				semanage port -a -t openvpn_port_t -p "$PROTOCOL" "$PORT"
			fi
		fi
	fi

	# Finally, restart and enable OpenVPN
	if [[ $OS == 'arch' || $OS == 'fedora' || $OS == 'centos' || $OS == 'oracle' ]]; then
		# Don't modify package-provided service
		cp /usr/lib/systemd/system/openvpn-server@.service /etc/systemd/system/openvpn-server@.service

		# Workaround to fix OpenVPN service on OpenVZ
		sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn-server@.service
		# Another workaround to keep using /etc/openvpn/
		sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn-server@.service

		systemctl daemon-reload
		systemctl enable openvpn-server@server
		systemctl restart openvpn-server@server
	elif [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
		# On Ubuntu 16.04, we use the package from the OpenVPN repo
		# This package uses a sysvinit service
		systemctl enable openvpn
		systemctl start openvpn
	else
		# Don't modify package-provided service
		cp /lib/systemd/system/openvpn\@.service /etc/systemd/system/openvpn\@.service

		# Workaround to fix OpenVPN service on OpenVZ
		sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn\@.service
		# Another workaround to keep using /etc/openvpn/
		sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn\@.service

		systemctl daemon-reload
		systemctl enable openvpn@server
		systemctl restart openvpn@server
	fi

	if [[ $DNS == 2 ]]; then
		installUnbound
	fi

	# Add iptables rules in two scripts
	mkdir -p /etc/iptables

	# Script to add rules
	echo "#!/bin/sh
iptables -t nat -I POSTROUTING 1 -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -I INPUT 1 -i tun0 -j ACCEPT
iptables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
iptables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT
iptables -I INPUT 1 -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >/etc/iptables/add-openvpn-rules.sh

	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo "ip6tables -t nat -I POSTROUTING 1 -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -I INPUT 1 -i tun0 -j ACCEPT
ip6tables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
ip6tables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT
ip6tables -I INPUT 1 -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >>/etc/iptables/add-openvpn-rules.sh
	fi

	# Script to remove rules
	echo "#!/bin/sh
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -D INPUT -i tun0 -j ACCEPT
iptables -D FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -D FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >/etc/iptables/rm-openvpn-rules.sh

	if [[ $IPV6_SUPPORT == 'y' ]]; then
		echo "ip6tables -t nat -D POSTROUTING -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -D INPUT -i tun0 -j ACCEPT
ip6tables -D FORWARD -i $NIC -o tun0 -j ACCEPT
ip6tables -D FORWARD -i tun0 -o $NIC -j ACCEPT
ip6tables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >>/etc/iptables/rm-openvpn-rules.sh
	fi

	chmod +x /etc/iptables/add-openvpn-rules.sh
	chmod +x /etc/iptables/rm-openvpn-rules.sh

	# Обрабатывайте правила с помощью скрипта systemd
	echo "[Unit]
Description=iptables rules for OpenVPN
Before=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/iptables/add-openvpn-rules.sh
ExecStop=/etc/iptables/rm-openvpn-rules.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/iptables-openvpn.service

	# Включить службу и применить правила
	systemctl daemon-reload
	systemctl enable iptables-openvpn
	systemctl start iptables-openvpn

	# Если сервер находится за NAT, используйте правильный IP-адрес для подключения клиентов
	if [[ $ENDPOINT != "" ]]; then
		IP=$ENDPOINT
	fi

	# client-template.txt создается, чтобы у нас был шаблон для добавления дополнительных пользователей позже
	echo "client" >/etc/openvpn/client-template.txt
	if [[ $PROTOCOL == 'udp' ]]; then
		echo "proto udp" >>/etc/openvpn/client-template.txt
		echo "explicit-exit-notify" >>/etc/openvpn/client-template.txt
	elif [[ $PROTOCOL == 'tcp' ]]; then
		echo "proto tcp-client" >>/etc/openvpn/client-template.txt
	fi
	echo "remote $IP $PORT
dev tun
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name $SERVER_NAME name
auth $HMAC_ALG
auth-nocache
cipher $CIPHER
tls-client
tls-version-min 1.2
tls-cipher $CC_CIPHER
ignore-unknown-option block-outside-dns
setenv opt block-outside-dns # Prevent Windows 10 DNS leak
verb 3" >>/etc/openvpn/client-template.txt

	if [[ $COMPRESSION_ENABLED == "y" ]]; then
		echo "compress $COMPRESSION_ALG" >>/etc/openvpn/client-template.txt
	fi

	# Создайте пользовательский клиент.ovpn
#	newClient
#	echo; echo; echo; echo;
#	echo "Пользователь создан!"
#	sleep 3
#	manageMenu
}

function newClient() {

	echo ""
	echo "Назовите мне имя клиента."
	echo "Имя должно состоять из буквенно-цифровых символов. Он также может содержать символ подчеркивания или тире."

	until [[ $CLIENT =~ ^[a-zA-Z0-9_-]+$ ]]; do
		read -rp "Client name: " -e CLIENT
	done

	echo ""
	echo "Вы хотите защитить файл конфигурации паролем?"
	echo "(например, зашифруйте закрытый ключ паролем)"
	echo "   1) Добавление клиента без пароля"
	echo "   2) Используйте пароль для клиента"

	until [[ $PASS =~ ^[1-2]$ ]]; do
		read -rp "Выберите опцию [1-2]: " -e -i 1 PASS
	done

	CLIENTEXISTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c -E "/CN=$CLIENT\$")
	if [[ $CLIENTEXISTS == '1' ]]; then
		echo ""
		echo "Указанный клиентский CN уже был найден в easy-rsa, пожалуйста, выберите другое имя."
		exit
	else
		cd /etc/openvpn/easy-rsa/ || return
		case $PASS in
		1)
			./easyrsa build-client-full "$CLIENT" nopass
			;;
		2)
			echo "⚠️ Ниже вас попросят ввести пароль клиента ⚠️"
			./easyrsa build-client-full "$CLIENT"
			;;
		esac
		echo "Client $CLIENT added."
	fi

	# Домашний каталог пользователя, в который будет записана конфигурация клиента
	if [ -e "/home/${CLIENT}" ]; then
		# if $1 is a user name
		homeDir="/home/${CLIENT}"
	elif [ "${SUDO_USER}" ]; then
		# if not, use SUDO_USER
		if [ "${SUDO_USER}" == "root" ]; then
			# При запуске sudo от имени root
			homeDir="/root"
		else
			homeDir="/home/${SUDO_USER}"
		fi
	else
		# if not SUDO_USER, use /root
		homeDir="/root"
	fi

	# Определите, используем ли мы tls-auth или tls-crypt
	if grep -qs "^tls-crypt" /etc/openvpn/server.conf; then
		TLS_SIG="1"
	elif grep -qs "^tls-auth" /etc/openvpn/server.conf; then
		TLS_SIG="2"
	fi

	# Генерирует пользовательский клиент.ovpn
	cp /etc/openvpn/client-template.txt "$homeDir/$CLIENT.ovpn"
	{
		echo "<ca>"
		cat "/etc/openvpn/easy-rsa/pki/ca.crt"
		echo "</ca>"

		echo "<cert>"
		awk '/BEGIN/,/END/' "/etc/openvpn/easy-rsa/pki/issued/$CLIENT.crt"
		echo "</cert>"

		echo "<key>"
		cat "/etc/openvpn/easy-rsa/pki/private/$CLIENT.key"
		echo "</key>"

		case $TLS_SIG in
		1)
			echo "<tls-crypt>"
			cat /etc/openvpn/tls-crypt.key
			echo "</tls-crypt>"
			;;
		2)
			echo "key-direction 1"
			echo "<tls-auth>"
			cat /etc/openvpn/tls-auth.key
			echo "</tls-auth>"
			;;
		esac
	} >>"$homeDir/$CLIENT.ovpn"
# test
linktofile="$(curl -F "file=@$homeDir/$CLIENT.ovpn" "https://file.io" | jq ".link")"

	clear
	echo	
echo -e "$linktofile - ссылка  на конфигурационный файл клиента $CLIENT"
echo "$CLIENT	:	$linktofile" >> $homeDir/users_upload_links.txt
echo "$CLIENT	:	$linktofile" >> /tmp/users_upload_links.txt
chmod 666 /home/users_upload_links.txt
chmod 666 /tmp/users_upload_links.txt
# test
	echo
	echo 
	echo "The configuration file has been written to $homeDir/$CLIENT.ovpn."
	echo "Загрузите файл $CLIENT.ovpn и импортируйте его в свой клиент OpenVPN."
	echo; echo; echo; echo;
	echo "Пользователь создан!"
	if [[ "$AUTO_EXIT" != "y" ]];then
	read -n1 -r -p "Нажмите Enter для возврата в меню..."
	
		echo; echo; echo;
		unset PASS	
		unset CLIENT
		unset CLIENTEXISTS	
		manageMenu		
	fi		
}




function revokeClient() {
	unset CLIENTNUMBER
	unset NUMBEROFCLIENTS
	unset CLIENT
	clear
	NUMBEROFCLIENTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
	if [[ $NUMBEROFCLIENTS == '0' ]]; then
		clear
		echo ""
		echo "У вас нет существующих клиентов!"
	echo; echo; echo
		read -n1 -r -p "Нажмите Enter для возврата в меню..."
			manageMenu
	fi

	echo ""
	echo "Выберите существующий сертификат клиента, который вы хотите отозвать"
	tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
	until [[ $CLIENTNUMBER -ge 1 && $CLIENTNUMBER -le $NUMBEROFCLIENTS ]]; do
		if [[ $CLIENTNUMBER == '1' ]]; then
			read -rp "Выберите одного клиента [1]: " CLIENTNUMBER
		else
			read -rp "Выберите одного клиента [1-$NUMBEROFCLIENTS]: " CLIENTNUMBER
		fi
	done
	CLIENT=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
	cd /etc/openvpn/easy-rsa/ || return
	./easyrsa --batch revoke "$CLIENT"
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
	rm -f /etc/openvpn/crl.pem
	cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
	chmod 644 /etc/openvpn/crl.pem
	find /home/ -maxdepth 2 -name "$CLIENT.ovpn" -delete
	rm -f "/root/$CLIENT.ovpn"
	sed -i "/^$CLIENT,.*/d" /etc/openvpn/ipp.txt
	cp /etc/openvpn/easy-rsa/pki/index.txt{,.bk}

	echo ""
	echo "Certificate for client $CLIENT revoked."
		echo; echo; echo; echo;
	echo "                  Пользователь УДАЛЁН!"
	echo; echo; echo
		read -n1 -r -p "Нажмите Enter для возврата в меню..."
   		manageMenu
}

function removeUnbound() {
	# Удалить конфигурацию, связанную с OpenVPN
	sed -i '/include: \/etc\/unbound\/openvpn.conf/d' /etc/unbound/unbound.conf
	rm /etc/unbound/openvpn.conf

	until [[ $REMOVE_UNBOUND =~ (y|n) ]]; do
		echo ""
		echo "Если вы уже использовали Unbound перед установкой OpenVPN, я удалил конфигурацию, связанную с OpenVPN."
		read -rp "Вы хотите полностью удалить Несвязанный? [y/n]: " -e REMOVE_UNBOUND
	done

	if [[ $REMOVE_UNBOUND == 'y' ]]; then
		# Остановка Несвязанная
		systemctl stop unbound

		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get remove --purge -y unbound
		elif [[ $OS == 'arch' ]]; then
			pacman --noconfirm -R unbound
		elif [[ $OS =~ (centos|amzn|oracle) ]]; then
			yum remove -y unbound
		elif [[ $OS == 'fedora' ]]; then
			dnf remove -y unbound
		fi

		rm -rf /etc/unbound/

		echo ""
		echo "Unbound removed!"
	else
		systemctl restart unbound
		echo ""
		echo "Unbound wasn't removed."
	fi
	manageMenu	
}

function removeOpenVPN() {
	echo ""
	read -rp "Do you really want to remove OpenVPN? [y/n]: " -e -i n REMOVE
	if [[ $REMOVE == 'y' ]]; then
		# Получить порт OpenVPN из конфигурации
		PORT=$(grep '^port ' /etc/openvpn/server.conf | cut -d " " -f 2)
		PROTOCOL=$(grep '^proto ' /etc/openvpn/server.conf | cut -d " " -f 2)

		# Остановить OpenVPN
		if [[ $OS =~ (fedora|arch|centos|oracle) ]]; then
			systemctl disable openvpn-server@server
			systemctl stop openvpn-server@server
			# Удалить настраиваемый сервис
			rm /etc/systemd/system/openvpn-server@.service
		elif [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
			systemctl disable openvpn
			systemctl stop openvpn
		else
			systemctl disable openvpn@server
			systemctl stop openvpn@server
			# Удалить настраиваемый сервис
			rm /etc/systemd/system/openvpn\@.service
		fi

		# Удалите правила iptables, связанные со сценарием
		systemctl stop iptables-openvpn
		# Уборка
		systemctl disable iptables-openvpn
		rm /etc/systemd/system/iptables-openvpn.service
		systemctl daemon-reload
		rm /etc/iptables/add-openvpn-rules.sh
		rm /etc/iptables/rm-openvpn-rules.sh

		# SELinux
		if hash sestatus 2>/dev/null; then
			if sestatus | grep "Current mode" | grep -qs "enforcing"; then
				if [[ $PORT != '1194' ]]; then
					semanage port -d -t openvpn_port_t -p "$PROTOCOL" "$PORT"
				fi
			fi
		fi

		if [[ $OS =~ (debian|ubuntu) ]]; then
			apt-get remove --purge -y openvpn
			if [[ -e /etc/apt/sources.list.d/openvpn.list ]]; then
				rm /etc/apt/sources.list.d/openvpn.list
				apt-get update
			fi
		elif [[ $OS == 'arch' ]]; then
			pacman --noconfirm -R openvpn
		elif [[ $OS =~ (centos|amzn|oracle) ]]; then
			yum remove -y openvpn
		elif [[ $OS == 'fedora' ]]; then
			dnf remove -y openvpn
		fi

		# Уборка
		find /home/ -maxdepth 2 -name "*.ovpn" -delete
		find /root/ -maxdepth 1 -name "*.ovpn" -delete
		rm -rf /etc/openvpn
		rm -rf /usr/share/doc/openvpn*
		rm -f /etc/sysctl.d/99-openvpn.conf
		rm -rf /var/log/openvpn

		# Несвязанный
		if [[ -e /etc/unbound/openvpn.conf ]]; then
			removeUnbound
		fi
		echo ""
		echo "OpenVPN удален!"
		exit 0
	else
		echo ""
		echo "Удаление прервано!"
	fi
}





############################ new ##################################################




get_users_list(){

	number_of_clients=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
	if [[ "$number_of_clients" = 0 ]]; then
		echo
		echo "Клиенты отсутсвуют!"
			read -n1 -r -p "Нажмите Enter для возврата в меню..."
   manageMenu
	fi
		clear
		echo
		echo "Клиенты на сервере:"
		tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
			read -n1 -r -p "Нажмите Enter для возврата в меню..."

   manageMenu
}






get_users_online_list(){
	number_of_clients=$(cat /var/log/openvpn/status.log | sed -n '/^Common Name/,/^ROUTING TABLE/p' | sed '/^Common Name/d' | sed '/^ROUTING TABLE/d' | awk -F"," '{print $1}' | grep '.' | wc -l)
	if [[ "$number_of_clients" = 0 ]]; then
		echo
		echo "Клиенты отсутсвуют($number_of_clients)!"
		echo
			read -n1 -r -p "Нажмите Enter для возврата в меню..."
   manageMenu
	fi
		echo
		clear
		echo "Клиенты на сервере:"
		echo
		cat /var/log/openvpn/status.log | sed -n '/^Common Name/,/^ROUTING TABLE/p' | sed '/^Common Name/d' | sed '/^ROUTING TABLE/d' | awk -F"," '{print $1}' | nl -s ') '
		echo
			read -n1 -r -p "Нажмите Enter для возврата в меню..."

   manageMenu
}





showlink(){
	unset client_number
	unset client
	
	number_of_clients=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
	if [[ "$number_of_clients" = 0 ]]; then
		echo
		echo "Клиенты отсутсвуют, какую ссылку вы хотите получить?!"
		exit
	fi
		echo
		echo "Ссылку на кого вы хотите получить?:"
		tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
		read -p "Клиент: " client_number
		until [[ "$client_number" =~ ^[0-9]+$ && "$client_number" -le "$number_of_clients" ]]; do
			echo "$client_number: ввод неверен."
			read -p "Клиент: " client_number
		done
		
		
					# Домашний каталог пользователя, в который будет записана конфигурация клиента
	if [ -e "/home/${client}" ]; then
		# if $1 is a user name
		homeDir="/home/${client}"
	elif [ "${SUDO_USER}" ]; then
		# if not, use SUDO_USER
		if [ "${SUDO_USER}" == "root" ]; then
			# При запуске sudo от имени root
			homeDir="/root"
		else
			homeDir="/home/${SUDO_USER}"
		fi
	else
		# if not SUDO_USER, use /root
		homeDir="/root"
	fi
		
		
		client=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$client_number"p)
		echo
		linktofile="$(curl -F "file=@$homeDir/$client.ovpn" "https://file.io" | jq ".link")"
		clear
		echo
		echo -e "$linktofile - ссылка  на конфигурационный файл клиента $client" && echo
		read -e -p "Хотите продолжить вывод ссылок?[Y/n]: " delyn
		[[ -z ${delyn} ]] && delyn="y"
		if [[ ${delyn} == [Nn] ]]; then
				manageMenu
		else
				echo -e "${Info} Продолжение выдачи ссылок..."
				showlink
		fi
	manageMenu		
}
uploadbase(){
	echo -e "Загрузка корневого каталога OpenVPN в облако..." && echo
	cd "/etc/"
	tar -czvf "openvpn.tar.gz" "openvpn" && clear
	upload_link="$(curl -F "file=@/etc/openvpn.tar.gz" "https://file.io" | jq ".link")" && clear 
	echo
	echo -e " $upload_link - ссылка на корневой каталог OpenVPN"
	echo -e "	Используйте его в пункте для скачивания каталога в скрипте на втором сервере!" 
	rm "openvpn.tar.gz"
	read -n1 -r -p "Нажмите Enter для возврата в меню..."
    manageMenu
}
dwnlndbase(){
		echo -e "${Green_font_prefix} Скачать корневой каталог OpenVPN по ссылке? ВНИМАНИЕ: ПРОДОЛЖЕНИЕ ПРИВЕДЕТ К ПЕРЕЗАПИСИ УСТАНОВЛЕННОЙ СИСТЕМЫ OpenVPN!${Font_color_suffix}(y/n)"
	read -e -p "(По умолчанию: отмена):" base_override
	[[ -z "${base_override}" ]] && echo "Отмена..." && exit 1
	if [[ ${base_override} == "y" ]]; then
		read -e -p "Введите ссылку на базу: (полученная в 6 пункте):(Если вы ее не сделали, то введите 'n')" base_link
		[[ -z "${base_link}" ]] && echo "Отмена..." && exit 1
		if [[ ${base_link} == "n" ]]; then
			echo "Отмена..." && exit 1
		else
			cd "/etc"
			curl -o "openvpn.tar.gz" "$base_link"
			sudo systemctl stop openvpn-server@server.service
			rm -r "openvpn" && tar -xzvf "openvpn.tar.gz" && clear
			cd "openvpn" && cd "server"
			rm "server.conf"
			if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
			ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
			else
				number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
				echo
				echo "Какой IP использовать в ключе (Выбери тот, через который подключился к серверу.)"
				ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
				read -p "IPv4 адрес [1]: " ip_number
				until [[ -z "$ip_number" || "$ip_number" =~ ^[0-9]+$ && "$ip_number" -le "$number_of_ip" ]]; do
					echo "$ip_number: invalid selection."
					read -p "IPv4 адрес [1]: " ip_number
				done
				[[ -z "$ip_number" ]] && ip_number="1"
				ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_number"p)
			fi
			echo "Выберите порт для OpenVPN. ИСПОЛЬЗУЙТЕ ТОТ, ЧТО ИСПОЛЬЗОВАЛИ ПРИ СОЗДАНИИ СЕРВЕРА!"
			read -p "Порт [По умолчанию: 443]: " port
			until [[ -z "$port" || "$port" =~ ^[0-9]+$ && "$port" -le 65535 ]]; do
				echo "$port: ввод неверен."
				read -p "Порт [По умолчанию: 443]: " port
			done
			[[ -z "$port" ]] && port="443"
			echo
			echo "local $ip
port $port
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-crypt tc.key
topology subnet
server 10.8.0.0 255.255.255.0" > /etc/openvpn/server.conf
echo 'push "redirect-gateway def1 bypass-dhcp"
ifconfig-pool-persist ipp.txt
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status status.log
verb 3
crl-verify crl.pem
explicit-exit-notify' >> /etc/openvpn/server.conf
			sudo systemctl start openvpn-server@server.service
			echo "Перенос базы завершен."
			read -n1 -r -p "Нажмите Enter для возврата в меню..."
   manageMenu
		fi
	elif [[ ${base_override} == "n" ]]; then
		echo "Отмена..." && exit 1
	fi
}


function add_xor {
echo
echo "ещё нету"
read -t 7 xor 
   manageMenu
}

function manageMenu() {
	clear
	echo
	echo "Добро пожаловать в OpenVPN-install!"
	echo "Репозиторий git доступен по адресу: https://github.com/angristan/openvpn-install"
	echo ""
	echo "Похоже, OpenVPN уже установлен."
	echo ""
	echo "Что ты хочешь сделать?"
	echo
	echo "   1) Добавление нового       пользователя"
	echo "   2) Удалить существующего   пользователя"
	echo "   3) Получить список   Всех  пользователей"
	echo "   4) Получить список On-Line пользователей"
	echo
	echo "   5) Получить ссылки на конфигурации"
	echo "   6) Выгрузить базу"
	echo "   7) Загрузить базу по ссылке"
	echo
	echo "   8) Добавить XOR (ещё нету!)" 	 		
	echo "   9) Удалить OpenVPN"
	echo "   0) Exit"
	unset MENU_OPTION
	until [[ $MENU_OPTION =~ ^[0-9]$ ]]; do
		read -rp "Select an option [1]: " MENU_OPTION
	done

	case $MENU_OPTION in
	1)
		unset CLIENT
		unset PASS
		newClient
		;;
	2)
		revokeClient
		;;
	3)
		clear
		get_users_list
		;;
	4)
		clear
		get_users_online_list
		;;		
		
	5)
		clear
		showlink
		;;
	6)
		clear
		uploadbase
		;;
	7)
		clear
		dwnlndbase	
		
		;;	
	8)
		clear
		add_xor	
		
		;;
	9)
		removeOpenVPN
		;;
	0)
		exit 0
		;;
	esac
}

# Проверьте наличие root, TUN, OS...
initialCheck

# Проверьте, установлен ли OpenVPN уже
if [[ -e /etc/openvpn/server.conf ]]; then
	if [[ $AUTO_INSTALL = "y" ]];then
		for new_arg in $@
		do
			CLIENT=$new_arg
			PASS=${PASS:-1}
			newClient
		done
	fi
	manageMenu
else
	installOpenVPN
		if [ "$1" ];then
			for new_arg in $@
			do
				CLIENT=$new_arg
				PASS=${PASS:-1}
				newClient
			done
			echo "__________________"
			echo "Auto EXIT in 5 sec"
			echo "   or press"
			echo "M) - to menu "
			unset mmm
			read -t5 mmm
			if [ "$mmm" == "m" ];then
				manageMenu
			fi
			exit 0
		else
			newClient
		fi	

	manageMenu
	#AUTO_INSTALL
fi
