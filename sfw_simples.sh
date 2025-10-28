#!/bin/bash

USUARIO=sysadmin
SENHA=123pizza

sudo apt update -y

sudo apt install openjdk-24-jdk -y
sudo apt install unzip -y

sudo useradd ${USUARIO} -m
echo "${USUARIO}:${SENHA}" | sudo chpasswd ${USUARIO} 
sudo usermod -aG sudo ${USUARIO}
sudo usermod -s /bin/bash ${USUARIO}

sudo mkdir /home/${USUARIO}/.ssh
sudo cp /home/ubuntu/.ssh/authorized_keys /home/${USUARIO}/.ssh
sudo chown -R ${USUARIO}:${USUARIO} /home/${USUARIO}/.ssh
sudo chmod 700 /home/${USUARIO}/.ssh
sudo chmod 600 /home/${USUARIO}/.ssh/authorized_keys

sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

sudo git clone https://github.com/Erick-Sptech/autobotics-java.git /home/${USUARIO}/autobotics-java

sudo chown -R ${USUARIO}:${USUARIO} /home/${USUARIO}/autobotics-java
