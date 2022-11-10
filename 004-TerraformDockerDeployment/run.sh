env=$1
if [ -z "$env" ]; then
    read -p $'Please enter the environment you wanted to deploy to: \n(example: test)\n' env
fi

if [ $env != "test" ] && [ $env != "test" ]; then
    echo "Error: Please enter the environment you are going to deploy to!\n(example: test)\n"
    exit 1
else
    echo "You are going to deploy to $env now!"
fi

terraform init -backend-config=config/$env/config.tfbackend

terraform plan -var-file=config/$env/$env.tfvars -out deploy.tfplan

yn=$2
if [ -z "$yn" ]; then
 read -p "Continue deploying? (y/n) " yn
fi
if [[ "$yn" =~ ^[yY] ]]; then terraform apply deploy.tfplan; fi

