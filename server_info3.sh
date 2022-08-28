#!/bin/bash
#green='\E[32;40m'
time=`date +%Y_%m_%d_%H-%M`
#name=`hostname`
#file=$HOME/Documents/$name"-System_info-"$time".txt"
## проверяем наличие старого файла. если он есть, удаляем
#if test -f /tmp/1.txt; then 
#rm $file
#fi

if [[ "$EUID" -ne 0 ]]; then # если пользователь рут 
clear
echo
echo " ВЫ НЕ ПОД РУТ"
echo
fi



file=/tmp/System_info-"$time".txt





make_group() {
test_group=$(cat /etc/group | awk -F":" '{print $1}' | grep "$1")

if [ "$test_group" ];then
	echo "группа уже существует"
else
	groupadd $1                                    # создаём группу (дл)
fi	
}





clear
loop=1;
while [ $loop -eq 1 ]
do
echo; echo; echo; echo; echo; echo; 
echo " 1) - Системная информация"
echo
echo "2 ) - Список всех Пользователей | /etc/passwd    (+awk)"
echo "21) -              только ЛЮДИ? | (UID >= 1000)(не macOS)"
echo "22) -              только ЛЮДИ? | users -команда не везде"
echo "23) -                           | compgen -u"
echo "24) -             Залогиненные? | w       -процессы?"
echo "25) -             Залогиненные? | who     -процессы?"
echo "26) -  Под каким я пользователем| whoami  - Я"
echo "27) -   посмотреть все процессы пользователя"
echo
echo " 3) - СОЗДАТЬ пользователя       (user,pass,group,dir....)"
echo
echo " 4) - СОЗДАТЬ Группа  "
echo "45) - Группа  пользователя -добавление -G "
echo "                                   (просмотр, замена, добавление, удаление) "
#echo "		 2a) - Группа  файла/папки  (просмотр, замена, добавление, удаление) "
echo
echo "7 ) создать общую папку"
echo "71) Рекурсивно - дать разрешения файлам внутри общей папке (chmod -R 2775...) "
echo

echo
echo " 9) - удалить пользователя"
echo
echo " 0 - Выйти из скрипта"

	  
#######################################################################################  
  


  read reply
  case "$reply" in
  
  
     	"1")
file="/tmp/sistem-info"		
echo -n > $file
echo -e "     Системная информация  ($time)" >> $file
echo "    ______________________" >> $file
echo >> $file
echo -e "          Имя Машины: \t" `dmidecode -s system-product-name` >> $file 
echo -e "         Имя Сервера: \t" `hostname` >> $file 
echo -e "                Ядро: \t" `uname -s` >> $file
echo -e "         Версия Ядра: \t" `uname -r` >> $file
echo -e "         Архитектура: \t" `uname -m` >> $file
echo -e "           Процессор: \t" `uname -p` >> $file
echo -e "Опирационная система: \t" `uname -o` >> $file
echo "______________________________________" >> $file
echo -e "          Видеокарта:" >> $file
lspci | grep -i vga >> $file
echo -e "               Аудио:" >> $file
lspci | grep -i audio >> $file
echo >> $file
echo -e "                Диск:" >> $file
fdisk -l | grep /dev >> $file
echo >> $file
echo -e "           USB входы:" >> $file
lsusb >> $file
echo >> $file
echo "                 Сеть:">> $file
echo >> $file
echo -e "Внутренний ip: \t" `ip route get 1 | awk -F"src " '{print $2}' | awk '{print $1}' | sed '/^$/d'` >> $file
echo -e "   Внешний ip: \t" `wget -qO- eth0.me` >> $file
echo -e "    Mac-адрес: \t" `ip addr show dev $(ip route ls | grep kernel | awk '{print $3}') | grep ether | awk '{print $2}'` >> $file
echo -e "   Интерфейсы:" >> $file
iwconfig >> $file
echo "______________________________________" >> $file
echo >> $file
echo "список установленных пакетов" >> $file
dpkg -l >> $file

cat $file
echo -e "$green========================================"
echo -e "$green Файл сохранён по пути:"
echo -e "$green              $file"
echo -e "$green========================================"; tput sgr0;
	  ;; 
	  
#######################################################################################  
  
	"2")
		echo  
		echo "все пользователи (/etc/passwd)"
		cat /etc/passwd | awk -F":" '{print $1}'
		read -t 10 xx
		echo
	  ;;
	  
	"21")
		echo  
		echo "все пользователи - ЛЮДИ (UID >= 1000)"
		cat /etc/passwd | awk -F":" '{if($3>=1000) print $1}'
		read -t 10 xx
		echo
	  ;;
	"22")
		echo  
		echo "все пользователи - ЛЮДИ (UID >= 1000)"
		users
		read -t 10 xx
		echo
	  ;; 
	"23")
		echo  
		echo "все пользователи         (compgen -u)"
		compgen -u
		read -t 10 xx
		echo
	  ;;
	"24")
		echo  
		echo " Залогиненные пользователи ( w )"
		w
		read -t 10 xx
		echo
	  ;;	  	   
	"25")
		echo  
		echo " Залогиненные пользователи ( who )"
		who
		read -t 10 xx
		echo
	  ;;
	"26")
		echo  
		echo " Залогиненные пользователи ( whoami )"
		whoami
		read -t 10 xx
		echo
	  ;;
	"27")
	  
	echo "посмотреть все процессы пользователя"
	read user_name
	# pgrep -u $user_name               # название процессов
	ps -f --pid $(pgrep -u $user_name) 2>/dev/null # подробно каждый процесс
	sleep 5
	  ;;	    
 
#######################################################################################  
   
	 
	"3")
		function show {

			clear
			echo
			echo "Создаём пользователя!"
			echo
			echo "useradd$kirilitsa$user_folder$groupB${password}$interpritator ${user_name}"
			echo
			echo
		
					}


show

echo "пиши USERNAME"
echo "латинскими буквами/цифрами, без пробелов,  "	
read user_name
show

echo "пароль"
echo "или <ENTER> - не использовать этот ключь"
read password

if [ "$password" ];then
pass="${password}"
password=" -p \"${password}\"" ;
fi
show


echo "пиши Имя Фамилию - (необязательно)"
echo "или <ENTER> - не использовать этот ключь"		
read kirilitsa
if [ "$kirilitsa" ];then kirilitsa=" -c \"${kirilitsa}\"" ; fi
show

echo "пиши папку пользователя"
echo "или     <Y> - для /home/$user_name "
echo "или <ENTER> - не использовать этот ключь "
	
read user_folder

if [ "$user_folder" ] && [ "$user_folder" != "y" ];then folder="$user_folder"; user_folder=" -d $user_folder"; fi
if [ "$user_folder" = "y" ];then folder="/home/$user_name"; user_folder=" -d /home/$user_name"; fi
show

echo "пиши Группу пользователя - (необязательно)"
echo "или     <Y> - группа будет как и имя($user_name) "
echo "или <ENTER> - не использовать этот ключь"		
read groupB
if [ "$groupB" ] && [ "$groupB" != "y" ];then group="$groupB"; groupB=" -g $groupB"; fi
if [ "$groupB" = "y" ];then group="$user_name"; groupB=" -g $user_name"; fi 
show

echo "пиши ИНТЕРПРИТАТОР"
echo "или     <Y> - для /bin/bash "
echo "или <ENTER> - не использовать этот ключь "
read interpritator
if [ "$interpritator" ] && [ "$interpritator" != "y" ];then interpritator=" -s $interpritator"; fi
if [ "$interpritator" = "y" ];then interpritator=" -s /bin/bash"; fi 
show
echo "команда сгенерирована"
sleep 1
dobavka=$(echo -n "useradd$kirilitsa$user_folder$groupB${password}$interpritator" ${user_name})


###########################

echo "создаём группу:$group (для пользователя)"	




make_group $group
	




	
sleep 1
echo " СОЗДАНИE ДОМАШНЕЙ ДИРЕКТОРИИ ПОЛЬЗОВАТЕЛЕЯ"
	mkdir -p $folder                             
sleep 1
echo "НАСЫЩАЮ ДОМАШНЮЮ ДИРЕКТОРИИ ПОЛЬЗОВАТЕЛЯ (из /etc/skel) если она есть"
if [ -d "/etc/skel" ];then
	cp -rT /etc/skel $folder 
fi	                      
sleep 1
echo "СОЗДАЮ ПОЛЬЗОВАТЕЛЕЯ"

#useradd -c "${name_kirilitsa}" -d /home/users/${user} -g "${gruppa}" -p password -s /bin/bash ${user}


echo -n "#!/bin/bash
$dobavka" > /tmp/doo
echo "команда записана в файл /tmp/doo"
sleep 1
echo "пытаюсь выполнить"
echo "--------------"
chmod +x /tmp/doo
/tmp/doo

if [ "${pass}" ];then
echo "даю пароль"
echo "${user_name}:${pass}" | chpasswd
echo ""
fi
# rm -f /tmp/doo


sleep 1
echo "НАДЕЛЯЮ ДИРЕКТОРИЮ ПРАВАМИ (${user_name}:$group)"
chown -R ${user_name}:$group $folder 
chmod -R 0750 $folder   

echo "наделить пользователя правами sudo?"
echo "(y) - да"
read ssudo
if [[ "$ssudo" =~ [yY] ]];then
usermod -aG sudo $user_name
	echo "Группа добавленна:"
	groups $user_name
sleep 3	
fi

echo "скопировать SSH ключь для этого пользователя?"
echo "(для доступа по ssh)"
echo "(y) - да"
read sssh
if [[ "$sssh" =~ [yY] ]];then
    cp -r ~/.ssh $folder
    chown -R ${user_name}:$group $folder/.ssh


	echo "Группа добавленна:"
	groups $user_name
fi

                   

#	pdpl-user -l 0:${yroven} ${user}                         # №12. ЗАДАЮ МАКСИМАЛЬНЫЙ УРОВЕНЬ КОНФИДЕНЦИАЛЬНОСТИ ДЛЯ ПОЛЬЗОВАТЕЛЕЯ
#	useraud ${user} ocxudntligarmphew:ocxudntligarmphew      # №13. ПОДКЛЮЧАЮ УСТАНОВКУ ПРАВИЛ ПРОТОКОЛИРОВАНИЯ ДЛЯ ПОЛЬЗОВАТЕЛЕЯ
echo
echo " ГОТОВО"
echo
		read -t 10 xx
	  ;;
	  
	  
	  
	  

#######################################################################################	  
	  
	  "4")
	  
	echo "напишите имя создаваемой группы"
	read group
	
	make_group $group
	echo "Группа создана!"
			read -t 10 xx
	  ;;
  
   	  "45")
	echo
	echo "добавить пользователю дополнительную группу (-G)"
	echo
	i=1
	for username in $(cat /etc/passwd | awk -F":" '{print $1}')
	do
	user[$i]=$username
	echo "$i) ${user[$i]}"
	i=$(($i+1))
	done
	echo "___________________"
	echo "выбери пользователя (номер):"
	read chois
	until [[ "$chois" =~ ^[0-9]*$ ]]; do
		echo "$RED Выбор неверный. Введите номер! $NC"
		read -p "  Ваш выбор$NC: " chois
	done
	
	username=${user[$chois]}
	echo "вы выбрали: $username"
	echo
	echo "напишите какую группу ему добавить:"
	
	i=1
	for group_name in $(cat /etc/group | awk -F":" '{print $1}')
	do
	group[$i]=$group_name
	echo "$i) ${group[$i]}"
	i=$(($i+1))
	done
	echo "___________________"
	echo "выбери Группу (номер):"
	echo "или"
	echo " впиши новую группу (она будет созданна и добавленна пользователю)"
	read chois
	
	if [[ "$chois" =~ ^[0-9]*$ ]];then
		group_name=${group[$chois]}

	else
		group_name="$chois"
		make_group $group_name
	fi
	
	
	echo "вы выбрали: u:|$username| g:|$group_name|"
	echo
	usermod -a -G $group_name $username
	echo "Группа добавленна:"
	groups $username
		read -t 10 xx	
	  ;; 
  
 
	
#######################################################################################	   
		  
			 
				   
  	  "7")
	echo  
	echo "создаю общую папку"
	echo
	echo "напишите полный путь и имя ОБЩЕЙ папки"
	echo "или (y) - для создания /home/shared"
	read shared_folder
	if [ "$shared_folder" = "y" ];then
	shared_folder="/home/shared"
	fi
	
	sleep 1
	mkdir -p "$shared_folder"
	echo "папка \"$shared_folder\" - Создана!"
	sleep 1
########	
group_name="${shared_folder##*/}" # выделяем имя папки из пути
echo "создаём группу:$group_name (для общей папки)"	

	
make_group $group_name                                   # создаём группу (общей папки )

	
sleep 1




	echo "НАДЕЛЯЮ ДИРЕКТОРИЮ ПРАВАМИ (${user_name}:$group)"
#	chown -R ${user_name}:$group_name $folder
echo "
chgrp -R $group_name  $shared_folder 
chmod -R 2775 $shared_folder"
	
	chgrp -R $group_name  $shared_folder 
	chmod -R 2775 $shared_folder
echo
echo " ГОТОВО"
echo
		read -t 10 xx
	  ;;
  
   	  "71") 
		if [ "$shared_folder" ];then
			chmod -R 2775 $shared_folder
		else
			echo "какую папку сделать общей для всех полбзователей:"
			read shared_folder
			chmod -R 2775 $shared_folder
		fi
		;;



#######################################################################################
  
    	"9")
		echo "Удаление Пользователя"
		echo "пиши username:"
		read user_name
		echo 
		echo "вы уверены что хотите удалить пользователя $user_name?"	
		echo ""	
		echo "будут удалены все его файлы из системы и домашняя директория"
		echo "(y) - Да ( + домашняя директория)"
		echo "(r) - Да ( + домашняя директория, и 'возможно' все его файлы у других пользователей)"
		echo "(enter) - НЕТ"
		read del
		
		
		if [ "$del" = "y" ];then
			echo "блокируем пользователя в системе"
			passwd --lock $user_name
			sleep 1
			echo "завершаем все его процессы"
#			sudo yum install psmisc                # для RedHat нужно установить пакет содержащий Killall		
			killall -9 -u $user_name
			sleep 1
			echo "удаление пользователя $user_name"
			userdel --remove $user_name            # Red Hat
#			deluser --remove-home $user_name       # Debian
		fi
		
		if [ "$del" = "r" ];then
			echo "блокируем пользователя в системе"
			passwd --lock $user_name
			sleep 1
			echo "завершаем все его процессы"
#			sudo yum install psmisc                # для RedHat нужно установить пакет содержащий Killall		
			killall -9 -u $user_name
			sleep 1
			echo "удаление пользователя $user_name"
			userdel --remove-all-files $user_name  # Red Hat со всеми его файлами (даже если системный файл принадлежал ему)
#			deluser --remove-all-files $user_name  # Debian  со всеми его файлами (даже если системный файл принадлежал ему) 

		fi
    sleep 3
	  ;;  
  
  
  
  

  
  
  
  
#######################################################################################






	"0")
	  loop=0
	  exit
	  ;;
  esac
done





exit 0




exit 0;
