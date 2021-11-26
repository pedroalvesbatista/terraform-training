terraform {
   required_providers = {
      aws = { 
        source  = "hashicorp/aws"
  	version = "~>3.8.0"
      }
   }
   
   required_version = "0.15.4"
}

provider "aws" {
   region = "sa-east-1"
   profile = "default"
} 
   	
      
