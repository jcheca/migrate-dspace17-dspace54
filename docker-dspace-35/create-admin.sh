#!/bin/bash
#need to be run to create admin for the container dspace ..

#stop tomcat daemon to be able to run dspace create-administrator
  sv stop tomcat8
  /dspace/bin/dspace database clean
  /dspace/bin/dspace create-administrator
  sv start tomcat8
  
