#Draft

1. Create a new Google Cloud project.

2. Enable the Compute Engine API.

3. Clone the repository:
   ```
   git clone https://github.com/oriasnoi/temp-devops-tsk8-terraform
   cd temp-devops-tsk8-terraform/provision
   ```

4. Edit the terraform.tfvars file.

5. Initialize and apply the Terraform configuration:
   ```
   terraform init
   terraform apply
   ```

6. Run:
   ```
   for i in {1..10}
   do
     curl <EXTERNAL-IP>:80
   done
   ```
