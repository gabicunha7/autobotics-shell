#!/bin/bash

USUARIO=sysadmin
SENHA=123pizza
SENHA_BD_ROOT=sptech

sudo apt update -y

sudo apt install nodejs -y
sudo apt install python3 -y
sudo apt install default-jdk -y
sudo apt install unzip -y
sudo apt install python3.12-venv -y
sudo apt install npm -y

sudo useradd ${USUARIO} -m
echo "${USUARIO}:${SENHA}" | sudo chpasswd ${USUARIO} 
sudo usermod -aG sudo ${USUARIO}
sudo usermod -aG docker ${USUARIO}
sudo usermod -s /bin/bash ${USUARIO}

sudo mkdir /home/${USUARIO}/.ssh
sudo cp /home/ubuntu/.ssh/authorized_keys /home/${USUARIO}/.ssh
sudo chown -R ${USUARIO}:${USUARIO} /home/${USUARIO}/.ssh
sudo chmod 700 /home/${USUARIO}/.ssh
sudo chmod 600 /home/${USUARIO}/.ssh/authorized_keys

sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo docker run --name mysql \
  -e MYSQL_ROOT_PASSWORD=${SENHA_BD_ROOT} \
  -p 3306:3306 \
  -d mysql:latest

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

sudo git clone https://github.com/gabicunha7/autobotics-agent.git /home/${USUARIO}/autobotics-agent
sudo git clone https://github.com/gabicunha7/autobotics.git /home/${USUARIO}/autobotics

sudo chown -R ${USUARIO}:${USUARIO} /home/${USUARIO}/autobotics-agent
sudo chown -R ${USUARIO}:${USUARIO} /home/${USUARIO}/autobotics

npm install --prefix /home/${USUARIO}/autobotics/site

sleep 10
sudo docker exec -i mysql mysql -u root -p${SENHA_BD_ROOT} < /home/${USUARIO}/autobotics/BD/Script-autobotics.sql

sudo python3 -m venv /home/${USUARIO}/autobotics-agent/venv
/home/${USUARIO}/autobotics-agent/venv/bin/pip install -r /home/${USUARIO}/autobotics-agent/requirements.txt
