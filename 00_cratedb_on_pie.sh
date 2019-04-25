#variables
declare_variables(){
  PIE_IP=$2
  ACTION=$1
  BASE_PATH=$3
  if [ -z "$3" ]
  then
    BASE_PATH="/res"
  fi

  echo "ip is the following: $PIE_IP"
  echo "the mode is : $ACTION"
}

prep_step(){
  # --- START - PRE STEP (should be done manually just once!) ---
  #install raspbian lite https://hackernoon.com/raspberry-pi-headless-install-462ccabd75d0

  #creating keys
  ssh-keygen
  #echo "test"

  #Adding keys to RPIs , it will ask for password
  ssh-copy-id pi@$PIE_IP
  #ssh-copy-id pi@192.168.0.102
  #ssh-copy-id pi@192.168.0.103

  # --- END - PRE STEP ---
}

init_raspi(){
  #cleanup step
  ssh pi@$PIE_IP rm -R /home/pi/crate
  ssh pi@$PIE_IP rm -R /home/pi/crate-src
  ssh pi@$PIE_IP rm -R /home/pi/crate-data
  ssh pi@$PIE_IP sudo rm -R /usr/java


  #Create folders
  ssh pi@$PIE_IP mkdir /home/pi/crate
  ssh pi@$PIE_IP mkdir /home/pi/crate-src
  ssh pi@$PIE_IP mkdir /home/pi/crate-data

  ssh pi@$PIE_IP chmod 777 /home/pi/crate-src
  ssh pi@$PIE_IP chmod 777 /home/pi/crate

  #Copying tarball to all pies
  scp $BASE_PATH/crate-*.tar.gz pi@$PIE_IP:/home/pi/crate-src
  scp $BASE_PATH/jdk-8u*.tar.gz pi@$PIE_IP:/home/pi/crate-src

  #install Java
  echo "-- unzipping JDK tar.gz"
  ssh pi@$PIE_IP sudo mkdir /usr/java
  ssh pi@$PIE_IP sudo tar -zxvf /home/pi/crate-src/jdk-8u*.tar.gz -C /usr/java
  ssh pi@$PIE_IP sudo rm /home/pi/crate-src/jdk-8u*.tar.gz
}

shutdown_raspi(){
  #shutdown raspberrypi
  ssh pi@$PIE_IP "sudo shutdown now"
}

config_java(){
  echo "-- adding JAVA_HOME to path"
  #configure java and add to path
  ssh pi@$PIE_IP "grep -q -F 'export JAVA_HOME=/usr/java/jdk1.8.0_181' ~/.bashrc || echo -e 'export JAVA_HOME=/usr/java/jdk1.8.0_181\nexport PATH=/usr/java/jdk1.8.0_181/bin:$PATH\n' | cat - ~/.bashrc > /home/pi/temp.txt && sudo mv /home/pi/temp.txt ~/.bashrc 2>/dev/null"
  #ssh pi@$PIE_IP "rm /home/pi/temp.txt"
  #ssh pi@$PIE_IP "grep -q -F 'export PATH=/usr/java/jdk1.8.0_181/bin:$PATH' ~/.bashrc || echo 'export PATH=/usr/java/jdk1.8.0_181/bin:$PATH' >>~/.bashrc"
  ssh pi@$PIE_IP "sudo sed -i '/-client IF_SERVER_CLASS -server/d' /usr/java/jdk1.8.0_181/jre/lib/arm/jvm.cfg"

}

configure_pi_for_crate(){
  #Copying configuration to RPI and then copy it as sudo in the right folder
  scp $BASE_PATH/limits.conf pi@$PIE_IP:/home/pi/crate-src/limits.conf
  scp $BASE_PATH/sysctl.conf pi@$PIE_IP:/home/pi/crate-src/sysctl.conf
  scp $BASE_PATH/crate pi@$PIE_IP:/home/pi/crate-src/crate
  ssh pi@$PIE_IP "sudo cp -rf /home/pi/crate-src/limits.conf /etc/security/limits.conf"
  ssh pi@$PIE_IP "sudo cp -rf /home/pi/crate-src/sysctl.conf /etc/sysctl.conf"
  ssh pi@$PIE_IP "sudo cp -rf /home/pi/crate-src/crate /etc/default/crate"

  ssh pi@$PIE_IP sudo sysctl -p

  #ssh pi@$PIE_IP "less ~/.bashrc"
  ssh pi@$PIE_IP sudo reboot now
}

copy_files_to_pi(){
  #Copying data to RPI and then copy it as sudo in the right folder. These files are to big, I'll switch to a python code that generates random data...
  scp $BASE_PATH/csv/iot_devices_1.csv pi@192.168.0.101:/home/pi/crate-src/iot_devices.csv
  scp $BASE_PATH/csv/iot_devices_2.csv pi@192.168.0.102:/home/pi/crate-src/iot_devices.csv
  scp $BASE_PATH/csv/iot_devices_3.csv pi@192.168.0.103:/home/pi/crate-src/iot_devices.csv

}

install_crate(){
  echo "this is the content of folder: /home/pi/crate-src"
  echo "-----"
  ssh pi@$PIE_IP ls /home/pi/crate-src
  echo "-----end of content-----"
  ssh pi@$PIE_IP rm -R /home/pi/crate/crate-*
  echo "-----Start Crate-----"
  echo "-- unzipping tar.gz"
  ssh pi@$PIE_IP tar -vxzf /home/pi/crate-src/crate-*.tar.gz -C /home/pi/crate
  scp $BASE_PATH/crate.yml pi@$PIE_IP:/home/pi/crate/crate-*/config/crate.yml
  #ssh pi@$PIE_IP /home/pi/crate/crate-*/bin/crate
}

start_crate(){
  #still not working, path is not the same as when ssh to pi, java missing
  ssh pi@$PIE_IP "/home/pi/crate/crate-*/bin/crate"
}

# Establish run order
main() {
    declare_variables $1 $2
    if [ "$ACTION" = "init" ]
    then
        init_raspi
        config_java
    elif [ "$ACTION" = "config" ]
    then
        configure_pi_for_crate
    elif [ "$ACTION" = "start" ]
      then
          start_crate
    elif [ "$ACTION" = "prepenv" ]
        then
           prep_step
    elif [ "$ACTION" = "copyfiles" ]
       then
          copy_files_to_pi
    elif [ "$ACTION" = "shutdown" ]
       then
          shutdown_raspi
    elif [ "$ACTION" = "install" ]
      then
          install_crate
    else
        echo "Usage sample:"
        echo "00_cratedb_on_pie init 192.168.0.101"
        echo "00_cratedb_on_pie config 192.168.0.101"
        echo "00_cratedb_on_pie install 192.168.0.101"
        echo "00_cratedb_on_pie start 192.168.0.101"
        echo "00_cratedb_on_pie prepenv 192.168.0.101"
        echo "00_cratedb_on_pie shutdown 192.168.0.101"
    fi
}

main $1 $2

#copy crate.yml from raspberrypi
#scp pi@$PIE_IP:/home/pi/crate/crate-3.0.5/config/crate.yml /gn/crate/crate.yml
#scp pi@$PIE_IP:/etc/security/limits.conf /gn/crate/limits.conf
#scp pi@$PIE_IP:/etc/sysctl.conf /gn/crate/sysctl.conf

#Have to manually run this on raspberrypi that have internet access (this part is wrong and obsolete)
# sudo apt-get purge openjdk-8-jre-headless
# sudo apt-get install openjdk-8-jre-headless
# sudo apt-get install openjdk-8-jre
# find $(dirname $(dirname $(readlink -f $(which java)))) -name jvm.cfg
# vim the file you find as per here https://askubuntu.com/questions/197965/openjdk-default-options-to-always-use-the-server-vm
#  sudo vim /usr/lib/jvm/java-8-openjdk-armhf/jre/lib/arm/jvm.cfg
#  /usr/java/jdk1.8.0_181/jre/lib/arm/jvm.cfg
