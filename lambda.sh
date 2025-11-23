#!/bin/bash
NOME_FUNCAO="lambda-autobotics"
ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)  
JAR_PATH="../autobotics-java/etl_autobotics/target/etl_autobotics-1.0-SNAPSHOT.jar"     
HANDLER="sptech.school.Handler"                       
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

aws s3api put-bucket-notification-configuration --bucket raw-$NOME_BUCKET --notification-configuration "{
  \"LambdaFunctionConfigurations\": [
    {
      \"LambdaFunctionArn\": \"arn:aws:lambda:us-east-1:$CONTA:function:$NOME_FUNCAO\",
      \"Events\": [\"s3:ObjectCreated:Put\"]
    }
  ]
}"