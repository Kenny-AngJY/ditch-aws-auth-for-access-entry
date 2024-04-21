### Check out my article on "Enhancing EKS Access Control: Ditch the aws-auth ConfigMap for Access Entry"
https://medium.com/@kennyangjy/enhancing-eks-access-control-ditch-the-aws-auth-configmap-for-access-entry-91683b47e6fc

![Enhancing EKS Access Control: Ditch the aws-auth ConfigMap for Access Entry](./IAM-EKS.jpg?raw=true "Enhancing EKS Access Control: Ditch the aws-auth ConfigMap for Access Entry")

---
> *Caution:* Cost will be involved in creating these resources. For more information, do visit the relavent resource pricing pages as it differs from region to region.
- https://aws.amazon.com/eks/pricing/
- https://aws.amazon.com/ec2/pricing/
---

### To provision the resources in this repository:
1. `git clone https://github.com/Kenny-AngJY/demystifying-aws-auth.git`
2. `terraform init`
3. `terraform plan`
<br>There should be 47 resources to be created.
4. `terraform apply`
<br>Give it 10-15 minutes for the apply to complete.

### Clean-up
1. `terraform destroy`