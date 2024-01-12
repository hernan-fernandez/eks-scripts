#!/bin/bash
### The following script will help you if you have the folling error in the EKS console.
### "Your current IAM principal doesn't have access to Kubernetes objects on this cluster."
### "This might be due to the current principal not having an IAM access entry with permissions to access the cluster."

### The script obtaning your current user/role from aws "sts get-caller-identity" and generate the corresponding configuration to be added to the aws-auth configuration
### 1.- Run this script to generate the configuration for your current user/role. This will create the file aws-auth-mapping.yaml
### 2.- Run this command to obtain your current aws-auth config map configuration "kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml"
### 3.- Add the detected configuration from aws-auth-mapping.yaml to your current configuration in aws-auth.yaml
### 4.- Apply the new configuration kubectl apply -f aws-auth.yaml

# Get IAM identity
identity=$(aws sts get-caller-identity)

# Parse identity data  
arn=$(echo $identity | jq -r '.Arn')
account_id=$(echo $identity | jq -r '.Account')
user_id=$(echo $identity | jq -r '.UserId')

# Handle assumed role ARN
if echo $arn | grep 'assumed-role' > /dev/null; then

  role=$(echo $arn | awk -F/ '{print $2}')
  role_arn="arn:aws:iam::$account_id:role/$role"
  
  mapping_type='mapRoles'
  principal_arn=$role_arn

else

  mapping_type='mapUsers'
  principal_arn="arn:aws:iam::$account_id:user/$user_id"

fi

# Generate config map entry
cat <<EOF > aws-auth-mapping.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  $mapping_type: |
    - $principal_arn:
        username: $user_id
        groups:
          - system:masters
EOF

echo "Generated: $(cat aws-auth-mapping.yaml)"
