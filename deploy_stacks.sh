#!/bin/bash

# Read the manifest file (manifest.yaml)
manifest="manifest.yaml"

# Loop through each stack definition in the manifest
for stack in $(yq e '.stacks[]' -o=j "$manifest"); do
  stackName=$(echo "$stack" | jq -r '.stackName')
  templateFile=$(echo "$stack" | jq -r '.templateFile')
  
  # Extract and format parameters if they exist
  parameters=""
  for param in $(echo "$stack" | jq -c '.parameters // empty | to_entries[]'); do
    key=$(echo "$param" | jq -r '.key')
    value=$(echo "$param" | jq -r '.value')
    parameters+=" ParameterKey=$key,ParameterValue=$value"
  done

  # Deploy the stack (use update-stack if stack exists, create-stack otherwise)
  echo "Deploying stack: $stackName with template: $templateFile"
  
  aws cloudformation describe-stacks --stack-name "$stackName" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Updating existing stack: $stackName"
    aws cloudformation update-stack --stack-name "$stackName" --template-body file://"$templateFile" --parameters $parameters --capabilities CAPABILITY_NAMED_IAM
    aws cloudformation wait stack-update-complete --stack-name "$stackName"
  else
    echo "Creating new stack: $stackName"
    aws cloudformation create-stack --stack-name "$stackName" --template-body file://"$templateFile" --parameters $parameters --capabilities CAPABILITY_NAMED_IAM
    aws cloudformation wait stack-create-complete --stack-name "$stackName"
  fi

  echo "Stack $stackName deployed successfully."
done
