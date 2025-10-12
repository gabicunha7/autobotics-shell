#!/bin/bash

NOME_CHAVE=meupardechaves
NOME_GRUPO=meugrupodeseguranca
NOME_EC2=web-server-01
ID_VPCS=$(aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId]' --output text)
ID_SUBNET=$(aws ec2 describe-subnets --query 'Subnets[1].SubnetId' --output text)
NOME_BUCKET=1d4a3f130793f4b0dfc576791dd86b04

echo "criando chave"
aws ec2 create-key-pair --key-name ${NOME_CHAVE} --region us-east-1 --query 'KeyMaterial' --output text > ${NOME_CHAVE}.pem
echo "chave criada com sucesso"

echo "criando grupo de segurança"
aws ec2 create-security-group --group-name ${NOME_GRUPO} --vpc-id ${ID_VPCS} --description "grupo de seguranca 42, para acesso ssh" --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sg-042}]'
echo "grupo criado com sucesso"

ID_GRUPO=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${NOME_GRUPO}" --query 'SecurityGroups[*].[GroupId]' --output text)

echo "permitindo acesso pela porta 22"
aws ec2 authorize-security-group-ingress --group-id ${ID_GRUPO} --protocol tcp --port 22 --cidr 0.0.0.0/0
echo "acesso permitido"

echo "permitindo acesso pela porta 3333"
aws ec2 authorize-security-group-ingress --group-id ${ID_GRUPO} --protocol tcp --port 3333 --cidr 0.0.0.0/0
echo "acesso permitido"

echo "permitindo acesso pela porta 80"
aws ec2 authorize-security-group-ingress --group-id ${ID_GRUPO} --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "acesso permitido"

echo "permitindo acesso ao mysql na porta 3306"
aws ec2 authorize-security-group-ingress --group-id ${ID_GRUPO} --protocol tcp --port 3306 --cidr 0.0.0.0/0
echo "acesso permitido"

echo "tentando rodar instancia"
aws ec2 run-instances --image-id ami-0360c520857e3138f --region us-east-1 --user-data file://sfw.sh --count 1 --security-group-ids ${ID_GRUPO} --instance-type t3.small --subnet-id ${ID_SUBNET} --key-name ${NOME_CHAVE} --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8, "VolumeType":"gp3","DeleteOnTermination":true}}]' --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NOME_EC2}}]" --query 'Instances[0].InstanceId' --output table
echo "ec2 está rodando"

echo "pegando id instancia para usar no ip elastico"
ID_INSTANCIA=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${NOME_EC2}" --query 'Reservations[*].Instances[*].InstanceId' --output text)
echo "peguei o id"

echo "criando ip elastico"
ID_IP=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --region us-east-1 --output text)
echo "ip criado"

while true; do
	ESTADO_INSTANCIA=$(aws ec2 describe-instances --instance-ids ${ID_INSTANCIA} --query 'Reservations[*].Instances[*].State.Name' --output text --region us-east-1)
	if [ "$ESTADO_INSTANCIA" == "running" ]; then
		echo "Instancia Rodando"
		echo "associando os dois"
		aws ec2 associate-address --instance-id ${ID_INSTANCIA} --allocation-id ${ID_IP} --region us-east-1
		break
	fi
	sleep 5
done

echo "Criando buckets"
aws s3api create-bucket --bucket raw-${NOME_BUCKET}
aws s3api create-bucket --bucket trusted-${NOME_BUCKET}
aws s3api create-bucket --bucket client-${NOME_BUCKET}
echo "Buckets criados"
