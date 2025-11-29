#!/bin/bash

NOME_CHAVE=meupardechaves
NOME_GRUPO=meugrupodeseguranca
NOME_EC2=web-server-01
ID_VPCS=$(aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId]' --output text)
ID_SUBNET=$(aws ec2 describe-subnets --query 'Subnets[1].SubnetId' --output text)
NOME_BUCKET=1d4a3f130793f4b0dfc576791dd86b32

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

echo "permitindo acesso na porta 8080"
aws ec2 authorize-security-group-ingress --group-id ${ID_GRUPO} --protocol tcp --port 8080 --cidr 0.0.0.0/0
echo "acesso permitido"

echo "tentando rodar instancia1"
aws ec2 run-instances --image-id ami-0360c520857e3138f --region us-east-1 --user-data file://sfw.sh --count 1 --security-group-ids ${ID_GRUPO} --instance-type t3.medium --subnet-id ${ID_SUBNET} --key-name ${NOME_CHAVE} --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":10, "VolumeType":"gp3","DeleteOnTermination":true}}]' --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NOME_EC2}}]" --query 'Instances[0].InstanceId' --output table
echo "ec2 está rodando1"

echo "pegando id instancia 1 para usar no ip elastico"
ID_INSTANCIA=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${NOME_EC2}" --query 'Reservations[*].Instances[*].InstanceId' --output text)
echo "peguei o id 1"

echo "criando ip elastico 1"
ID_IP=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --region us-east-1 --output text)
echo "ip criado 1"


while true; do
	ESTADO_INSTANCIA=$(aws ec2 describe-instances --instance-ids ${ID_INSTANCIA} --query 'Reservations[*].Instances[*].State.Name' --output text --region us-east-1)
	if [ "$ESTADO_INSTANCIA" == "running" ]; then
		echo "Instancia 1 Rodando"
		echo "associando os dois"
		aws ec2 associate-address --instance-id ${ID_INSTANCIA} --allocation-id ${ID_IP} --region us-east-1
		break
	fi
	sleep 5
done

echo "associando primeira instancia com labprofile"
aws ec2 associate-iam-instance-profile \
    --instance-id "$ID_INSTANCIA" \
    --iam-instance-profile Name="LabInstanceProfile"
echo "associada 1"

ENV_VALOR=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${NOME_EC2}" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

echo "Criando buckets"
aws s3api create-bucket --bucket raw-${NOME_BUCKET}
aws s3api create-bucket --bucket trusted-${NOME_BUCKET}
aws s3api create-bucket --bucket client-${NOME_BUCKET}
echo "Buckets criados"

echo "permitindo acesso externo aos buckets"
aws s3api put-public-access-block \
    --bucket raw-${NOME_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws s3api put-public-access-block \
    --bucket trusted-${NOME_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws s3api put-public-access-block \
    --bucket client-${NOME_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
echo "acesso permitido"

echo "adicionando politica de acesso aos buckets"
aws s3api put-bucket-policy --bucket raw-${NOME_BUCKET} --policy file://politica_raw.json

aws s3api put-bucket-policy --bucket trusted-${NOME_BUCKET} --policy file://politica_trusted.json

aws s3api put-bucket-policy --bucket client-${NOME_BUCKET} --policy file://politica_client.json

echo "politica adicionada"


NOME_FUNCAO="lambda-autobotics"
ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)  
JAR_PATH="../autobotics-java/etl_autobotics/target/etl_autobotics-1.0-SNAPSHOT.jar"     
HANDLER="school.sptech.Handler"                       
RUNTIME="java25"                                    
TIMEOUT=180                                         
ENV_CHAVE="BD_IP"
ENV_VALOR=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${NOME_EC2}" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

echo "criando lambda" 
aws lambda create-function --function-name "$NOME_FUNCAO" --runtime "$RUNTIME" --role "$ROLE_ARN" --handler "$HANDLER" --timeout "$TIMEOUT" --environment "Variables={$ENV_CHAVE=$ENV_VALOR}" --zip-file "fileb://$JAR_PATH" --output table

echo "criando url para lambda"
aws lambda create-function-url-config --function-name "$NOME_FUNCAO" --auth-type NONE --output table

CONTA=$(aws sts get-caller-identity --query "Account" --output text)
aws lambda add-permission --function-name "$NOME_FUNCAO" --statement-id S3InvokePermission --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn arn:aws:s3:::raw-$NOME_BUCKET --source-account $CONTA

echo "configurando trigger"
aws s3api put-bucket-notification-configuration --bucket raw-$NOME_BUCKET --notification-configuration "{
  \"LambdaFunctionConfigurations\": [
    {
      \"LambdaFunctionArn\": \"arn:aws:lambda:us-east-1:$CONTA:function:$NOME_FUNCAO\",
      \"Events\": [\"s3:ObjectCreated:*\"]
    }
  ]
}"

echo "criando lambda client"
NOME_FUNCAO_CLIENT="lambda-autobotics-client"
TIMEOUT_CLIENT=360                                       
JAR_PATH_CLIENT="../autobotics-java-client/etl_autobotics-client/target/etl_autobotics-1.0-SNAPSHOT.jar"     

aws lambda create-function --function-name "$NOME_FUNCAO_CLIENT" --runtime "$RUNTIME" --role "$ROLE_ARN" --handler "$HANDLER" --timeout "$TIMEOUT_CLIENT" --memory-size 512 --environment "Variables={$ENV_CHAVE=$ENV_VALOR}" --zip-file "fileb://$JAR_PATH_CLIENT" --output table
	
echo "criando url para lambda client"
aws lambda create-function-url-config --function-name "$NOME_FUNCAO_CLIENT" --auth-type NONE --output table

CONTA=$(aws sts get-caller-identity --query "Account" --output text)
aws lambda add-permission --function-name "$NOME_FUNCAO_CLIENT" --statement-id S3InvokePermission --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn arn:aws:s3:::trusted-$NOME_BUCKET --source-account $CONTA

echo "configurando trigger"
aws s3api put-bucket-notification-configuration --bucket trusted-$NOME_BUCKET --notification-configuration "{
  \"LambdaFunctionConfigurations\": [
    {
      \"LambdaFunctionArn\": \"arn:aws:lambda:us-east-1:$CONTA:function:$NOME_FUNCAO_CLIENT\",
      \"Events\": [\"s3:ObjectCreated:*\"]
    }
  ]
}"