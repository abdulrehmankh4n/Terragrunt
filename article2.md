# Save our cluster's kubeconfig file

**Use AWS CLI to save kubeconfig file**

`aws eks update-kubeconfig --name <cluster_name>`

Be sure to replace `<cluster_name>` with the name of your EKS cluster. Mine is `eks-demo`.

**Check the kubeconfig file**

`cat ~/.kube/config`


# Download and apply EKS aws-auth

To grant our IAM principal the ability to interact with our EKS cluster, first download the `aws-auth` `ConfigMap`.

`curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/aws-auth-cm.yaml
`

We should then edit the downloaded `aws-auth-cm.yaml` file (using Vim or Nano) and replace `<ARN of instance role (not instance profile)>` with the ARN of our worker node IAM role (not its instance profile's ARN), then save the file.

We can then apply the configuration with the following line:

`kubectl apply -f aws-auth-cm.yaml`


# Configure Pod Security Group

In this section, we will:

- Create an Amazon RDS database protected by a security group called db_sg.
- Create a security group called pod_sg that will be allowed to connect to the RDS instance.
- Deploy a SecurityGroupPolicy that will automatically attach the pod_sg security group to a pod with the correct metadata.
- Deploy two pods (green and blue) using the same image and verify that only one of them (green) can connect to the Amazon RDS database.

**Create DB Security Group (db_sg)**

```
export VPC_ID=$(aws eks describe-cluster \
    --name eks-demo \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

# create DB security group
aws ec2 create-security-group \
    --description 'DB SG' \
    --group-name 'db_sg' \
    --vpc-id ${VPC_ID}

# save the security group ID for future use
export DB_SG=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=db_sg Name=vpc-id,Values=${VPC_ID} \
    --query "SecurityGroups[0].GroupId" --output text)
```

**NB:** If you have issues running the AWS commands, you might need to configure your AWS credentials. Check [this link](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) if you're not sure how to proceed.

**Create Pod Security Group (pod_sg)**

```
# create the Pod security group
aws ec2 create-security-group \
    --description 'POD SG' \
    --group-name 'pod_sg' \
    --vpc-id ${VPC_ID}

# save the security group ID for future use
export POD_SG=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=pod_sg Name=vpc-id,Values=${VPC_ID} \
    --query "SecurityGroups[0].GroupId" --output text)

echo "Pod security group ID: ${POD_SG}"
```

**Add Ingress Rules to db_sg**

One rule is to allow bastion host to populate DB, the other rule is to allow pod_sg to connect to DB.

```
# Get IMDSv2 Token
export TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`

# Instance IP
export INSTANCE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)

# allow instance to connect to RDS
aws ec2 authorize-security-group-ingress \
    --group-id ${DB_SG} \
    --protocol tcp \
    --port 5432 \
    --cidr ${INSTANCE_IP}/32

# Allow pod_sg to connect to the RDS
aws ec2 authorize-security-group-ingress \
    --group-id ${DB_SG} \
    --protocol tcp \
    --port 5432 \
    --source-group ${POD_SG}
```

**Configure Node Group's Security Group to Allow Pod to Communicate with its Node for DNS Resolution**

```
export NODE_GROUP_SG=$(aws ec2 describe-security-groups \
    --filters Name=tag:Name,Values=eks-cluster-sg-eks-demo-* Name=vpc-id,Values=${VPC_ID} \
    --query "SecurityGroups[0].GroupId" \
    --output text)
echo "Node Group security group ID: ${NODE_GROUP_SG}"

# allow pod_sg to connect to NODE_GROUP_SG using TCP 53
aws ec2 authorize-security-group-ingress \
    --group-id ${NODE_GROUP_SG} \
    --protocol tcp \
    --port 53 \
    --source-group ${POD_SG}

# allow pod_sg to connect to NODE_GROUP_SG using UDP 53
aws ec2 authorize-security-group-ingress \
    --group-id ${NODE_GROUP_SG} \
    --protocol udp \
    --port 53 \
    --source-group ${POD_SG}
```

**Create RDS DB**

This post assumes that you have some knowledge of RDS databases and won't focus on this step.

You should create a DB subnet group consisting of the 2 data subnets created in the [previous article](https://dev.to/aws-builders/provision-eks-cluster-with-terraform-terragrunt-github-actions-17lb-temp-slug-4495517?preview=9e6ecfec95fc72be3db2ae9073c0955d76056bdfb60674ee121faac132c32c4bda65f4bd325e27c7d4d3d708584afa126dd8fe139f118a394d75c7a0), and use this subnet group for the RDS database you're creating.

I have named my database `eks_demo` (DB name, not DB identifier), and this name is reference in some steps below. If you give your database a different name, you'll have to update this in the corresponding steps below.

**Populate DB with sample data**

```
sudo dnf update
sudo dnf install postgresql15.x86_64 postgresql15-server -y
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Use Vim to edit the postgresql.conf file to listen from all address
sudo vi /var/lib/pgsql/data/postgresql.conf

# Replace this line
listen_addresses = 'localhost'

# with the following line
listen_addresses = '*'

# Backup your postgres config file
sudo cp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.bck

# Allow connections from all addresses with password authentication
# First edit the pg_hba.conf file
sudo vi /var/lib/pgsql/data/pg_hba.conf
# Then add the following line to the file
host all all 0.0.0.0/0 md5

# Restart the postgres service
sudo systemctl restart postgresql

cat << EOF > sg-per-pod-pgsql.sql
CREATE TABLE welcome (column1 TEXT);
insert into welcome values ('--------------------------');
insert into welcome values ('  Welcome to the EKS lab  ');
insert into welcome values ('--------------------------');
EOF

psql postgresql://<RDS_USER>:<RDS_PASSWORD>@<RDS_ENDPOINT>:5432/<RDS_DATABASE_NAME>?ssl=true -f sg-per-pod-pgsql.sql
```

Be sure to replace `<RDS_USER>`, `<RDS_PASSWORD>`, `<RDS_ENDPOINT>` and `<RDS_DATABASE_NAME>` with the right values for your RDS database.

**Configure CNI to Manage Network Interfaces for Pods**

```
kubectl -n kube-system set env daemonset aws-node AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
kubectl -n kube-system set env daemonset aws-node ENI_CONFIG_LABEL_DEF=failure-domain.beta.kubernetes.io/zone
kubectl -n kube-system set env daemonset aws-node ENABLE_POD_ENI=true

# Wait for the rolling update of the daemonset
kubectl -n kube-system rollout status ds aws-node
```

Note that this requires the `AmazonEKSVPCResourceController` AWS-managed policy to be attached to the node group's role, that will allow it to manage ENIs and IPs for the worker nodes.

**Create SecurityGroupPolicy Custom Resource**

> A new Custom Resource Definition (CRD) has also been added automatically at the cluster creation. Cluster administrators can specify which security groups to assign to pods through the SecurityGroupPolicy CRD. Within a namespace, you can select pods based on pod labels, or based on labels of the service account associated with a pod. For any matching pods, you also define the security group IDs to be applied.

Verify the CRD is present with this command:

`kubectl get crd securitygrouppolicies.vpcresources.k8s.aws`

> The webhook watches SecurityGroupPolicy custom resources for any changes, and automatically injects matching pods with the extended resource request required for the pod to be scheduled onto a node with available branch network interface capacity. Once the pod is scheduled, the resource controller will create and attach a branch interface to the trunk interface. Upon successful attachment, the controller adds an annotation to the pod object with the branch interface details.

Next, create the policy configuration file:

```
cat << EOF > sg-per-pod-policy.yaml
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: allow-rds-access
spec:
  podSelector:
    matchLabels:
      app: green-pod
  securityGroups:
    groupIds:
      - ${POD_SG}
EOF
```

Finally, deploy the policy:

```
kubectl apply -f sg-per-pod-policy.yaml
kubectl describe securitygrouppolicy
```

**Create Secret for DB Access**

```
kubectl create secret generic rds --from-literal="password=<RDS_PASSWORD>" --from-literal="host=<RDS_ENDPOINT>"

kubectl describe secret rds
```

Make sure you replace `RDS_PASSWORD` and `RDS_ENDPOINT` with the correct values for your RDS database.

**Create Green and Blue Pods**

_green-deploy.yaml_

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: green-deploy
  name: green-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: green-pod
  template:
    metadata:
      labels:
        app: green-pod
    spec:
      containers:
      - image: rtdl/psql-client
        name: green-pod
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1024m"
        command:
        - "psql -h ${HOST} -p 5432 -U ${USER} --dbname ${DB_NAME}"
        env:
        - name: HOST
          valueFrom:
            secretKeyRef:
              name: rds
              key: host
        - name: DB_NAME
          value: eks_demo
        - name: USER
          value: eks-demo
        - name: PASSWORD
          valueFrom:
            secretKeyRef:
              name: rds
              key: password
```

The `blue-deploy.yaml` file will be exactly the same, but its names and labels will be `blue-deploy` and `blue-pod` instead of `green-deploy` and `green-pod` respectively.

You can check the logs of each pod using the command `kubectl logs <deployment_name>` (change `<deployment_name>` with either `green-deploy` or `blue-deploy`), and verify that only the green pods successfully connected to the RDS database.


# Network Policy Objectives
