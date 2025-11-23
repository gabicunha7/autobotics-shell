#!/bin/bash

echo "Excluindo instância"
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[-1].[InstanceId]" \
    --output text)

aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"

echo "excluindo par de chaves"
aws ec2 delete-key-pair --key-name meupardechaves
rm -f meupardechaves.pem

echo "Excluindo grupo de segurança"
SG_ID=$(aws ec2 describe-security-groups \
    --query "SecurityGroups[?contains(GroupName, 'meugrupodeseguranca')].[GroupId]" \
    --output text)
aws ec2 delete-security-group --group-id "$SG_ID"


ALLOCATTION_ID=$(aws ec2 describe-addresses \
    --query "Addresses[0].AllocationId" \
    --output text)

ASSOCIATION_ID=$(aws ec2 describe-addresses \
    --query "Addresses[0].AssociationId" \
    --output text)

echo "desassociando ip elastico"
aws ec2 disassociate-address --association-id "$ASSOCIATION_ID"
echo "liberando ip elastico"
aws ec2 release-address --allocation-id "$ALLOCATTION_ID"

RAW=raw-1d4a3f130793f4b0dfc576791dd86b32
TRUSTED=trusted-1d4a3f130793f4b0dfc576791dd86b32
CLIENT=client-1d4a3f130793f4b0dfc576791dd86b32

echo "Excluindo raw"
aws s3 rm s3://$RAW --recursive
aws s3 rb s3://$RAW --force

echo "Excluindo trusted"
aws s3 rm s3://$TRUSTED --recursive
aws s3 rb s3://$TRUSTED --force

echo -e "\nExcluindo client"
aws s3 rm s3://$CLIENT --recursive
aws s3 rb s3://$CLIENT --force