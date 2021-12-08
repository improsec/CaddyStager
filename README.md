# CaddyStager

This repository contains the Caddyfile, Terraform configuration and C# Stager seen in https://improsec/path/to/blogpost

## Description

Running the terraform code will configure two VM's on Azure with very basic configuration. The rest of the configuration is handled manually. It could be pushed to terraform to handle as well, however, for now it's done manually.
These two VM's will be configured with Ubuntu 20.04. One is for Caddy reverse-proxy, the other for Cobalt Strike.  
The caddyfile contains the configuration needed for the reverse-proxy, to ensure that only requests with a specfic user-agent and client certificated is allowed to stage.  
The C# Stager (CertStager) is just a simple C# stager that will authenticate to Caddy with a certificate.  

## Getting Started

### Dependencies

Get Terraform from https://www.terraform.io/downloads.html  
Get Azure CLI from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli  

### Executing

To get started, run the following commands:
```
git clone https://github.com/improsec/caddystager.git
cd C:\path\to\caddystager\terraform
```
place terraform.exe in the caddystager\terraform directory. Rember to change the IP range in "variables.tf" to include whatever range you want to allow ALL inbound from.  
```
az login
.\terraform init
.\terraform validate
.\terraform plan -out tfplan
.\terraform apply tfplan
.\terraform output keys
```
Wait a few minutes and verify that both VM's are up and running. Now configure Cobalt Strike on one and Caddy on the other.
Save the SSH key to a key.key file

Move Cobalt Strike to the new server
```
scp.exe -i key.key .\cobaltstrike-dist.tgz cobalt@cobaltmtls.northeurope.cloudapp.azure.com:/home/cobalt/
```

Edit C2concealer. Configuration can be seen in the blogpost.  
Install C2concealer  
```
chmod u+x install.sh
./install.sh
```
Open for HTTP+HTTPS on our Cobalt Strike server and run customized C2concealer.  
```
C2concealer --hostname caddymtls.northeurope.cloudapp.azure.com
```
After certificates are issed, go ahead and remove the HTTP+HTTPS inbound on Cobalt Strike. At this point, only inbound HTTPS requests from Caddy should be allowed.  
Setup a listener on Cobalt Strikke for HTTPS on port 443.  
Switch to the Caddy server and setup a local CA.  
```
cd /opt/certs
openssl genrsa -des3 -out localca.key 2048
openssl req -x509 -new -nodes -key localca.key -sha256 -days 30 -out localca.pem
openssl req -new -key client.key -out client.csr
openssl x509 -req -in client.csr -CA localca.pem -CAkey localca.key -CAcreateserial -out client.crt -days 20 -sha256
```
Get a DER from the CRT issed for our client certificate and base64 encode it:  
```
openssl x509 -in client.crt -out client.der -outform DER
base64 client.der
```

Insert the certificate in the Caddyfile at trsuted_leaf_cert.  
Change the CertStager to whatever URL you're provided with and insert the same base64 encoded client certificate in CertStager as well.  
Remember to change user-agents in the Caddyfile depending on which user agents C2concealer created.  


## Authors

Nichlas Falk  
[@biskopp3n](https://twitter.com/biskopp3n)

## Version History

* 0.1
    * Initial Release

## Acknowledgments

* [byt3bl33d3r caddyfile](https://gist.github.com/byt3bl33d3r/054e5c183a46c6c021a4bb8f1901c143)
* [byt3bl33d3r Taking the pain out of C2 Infrastructure](https://byt3bl33d3r.substack.com/p/taking-the-pain-out-of-c2-infrastructure)
* [FortyNorthSecurity C2concealer](https://github.com/FortyNorthSecurity/C2concealer)