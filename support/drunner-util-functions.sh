#!/bin/bash

#-----------------------------------------------------------------------------------------------------------------------------

# die MESSAGE 
# colourful way to die.
function die {
   if [ -n "$1" ]; then
      echo " ">&2 ; echo -e "\e[31m\e[1m${1}\e[0m">&2  ; echo " ">&2
   else
      echo " ">&2 ; echo -e "\e[31m\e[1mUnexpected error. Exiting.\e[0m">&2  ; echo " ">&2
      fi
   exit 1
}

#-----------------------------------------------------------------------------------------------------------------------------

# Global constants for pretty code.
# require  echo -e 
readonly CODE_S="\e[32m"
readonly CODE_E="\e[0m"

#-----------------------------------------------------------------------------------------------------------------------------

# dieusage USAGEMESSAGE
# die, showing how we should be used.
function dieusage {
   echo "Usage:">&2
   echo -e "   ${CODE_S}$1${CODE_E}" >&2
   exit 1
}

#-----------------------------------------------------------------------------------------------------------------------------

# check whether a docker volume exists on the host.
function volexists {
  docker volume ls | grep "$1" > /dev/null
}

#------------------------------------------------------------------------------------

# getUSERID IMAGENAME
# get the ID of the user running in a docker container.
function getUSERID {
   if [ -z "$1" ]; then die "getUSERID: requires IMAGENAME passed as first argument."; fi
   USERID=$(docker run --rm -it "${1}" /bin/bash -c "id -u | tr -d '\r\n'")
   if [ $? -ne 0 ]; then die "getUSERID: Docker image ${1} does not exist." ; fi
}

#------------------------------------------------------------------------------------

# command_exists
# see if the given command exists in the current users path
# if comannd_exists docker ; then ...
function command_exists { command -v "$1" >/dev/null 2>&1 ; }

#------------------------------------------------------------------------------------

# elementIn element array
# if elementIn "a string" "${array[@]}" ; then ...
function elementIn {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}


#------------------------------------------------------------------------------------

# validate-image
function validate-image  {
   if [ ! -v ROOTPATH ] || [ -z "$ROOTPATH" ]; then die "validate-image: ROOTPATH is not set." ; fi
   if [ ! -v IMAGENAME ] || [ -z "$IMAGENAME" ]; then die "validate-image: IMAGENAME is not set." ; fi
   if [ ! -e "${ROOTPATH}/support/validator-image" ]; then
      die "Missing dr file: ${ROOTPATH}/support/validator-image"
   fi
   docker run --rm -v "${ROOTPATH}/support:/support" "${IMAGENAME}" /bin/bash -c "/support/validator-image"
   if [ "$?" -ne 0 ]; then 
      die "${IMAGENAME} is not dRunner compatible."
   fi
   
   echo "${IMAGENAME} is dr compatible.">&2
}


#------------------------------------------------------------------------------------
# array2string "${arr[@]:-}" ; echo "$ARRAYSTR"
# the string is intended for outputting to a file - e.g. MYVAR="$ARRAYSTR", which can
# be read back in with source. Works with empty arrays, and empty strings in the array.

function array2string {
   ARRAYSTR=""
   if [ -n "$1" ]; then
      printf -v ARRAYSTR "\"%s\" " "$@"
   fi
   ARRAYSTR="(${ARRAYSTR% })"
}


#------------------------------------------------------------------------------------

# loadService [SKIPVALIDATION]
# if validation is skipped then it requires SERVICENAME and ROOTPATH, but copes with
# anything else.
function loadService {
   SKIPVALIDATION=${1:-""}   
   if [ ! -v SERVICENAME ] || [ -z "$SERVICENAME" ]; then die "loadService - SERVICENAME not defined." ; fi
   if [ -z $SKIPVALIDATION ]; then 
      bash "${ROOTPATH}/support/validator-service" "$SERVICENAME"
      if [ $? -ne 0 ]; then exit 1 ; fi
   fi
   
   if [ -e "${ROOTPATH}/services/${SERVICENAME}/drunner/servicecfg.sh" ]; then
      source "${ROOTPATH}/services/${SERVICENAME}/drunner/servicecfg.sh"
   fi
   
   if [ -e "${ROOTPATH}/services/${SERVICENAME}/imagename.sh" ]; then
      source "${ROOTPATH}/services/${SERVICENAME}/imagename.sh"
   fi
   
   if [ -v VOLUMES ]; then
      for i in "${!VOLUMES[@]}"; do
         DOCKERVOLS[$((i))]="drunner-${SERVICENAME}-${VOLUMES[i]//[![:alnum:]]/}"
         DOCKEROPTS[$((2*i))]="-v"
         DOCKEROPTS[$((2*i+1))]="${DOCKERVOLS[i]}:${VOLUMES[i]}"
      done
   fi
}

#------------------------------------------------------------------------------------

# destroy
# destroys everything we can about a service!
# requires both SERVICENAME and ROOTPATH to be set. Assumes nothing else.
function destroy {   
   # call destroy in service.
   if [ ! -v SERVICENAME ]; then 
      die "Can't destroy because SERVICENAME is not set."
   fi

   # attempt to read the service info, if present.
   loadService "SKIPVALIDATION"

   if [ -e "${ROOTPATH}/services/${SERVICENAME}/drunner/servicerunner" ]; then 
      bash "${ROOTPATH}/services/${SERVICENAME}/drunner/servicerunner" destroy
   fi
   
   # remove volume containers.
   if [ -v DOCKERVOLS ]; then
      for VOLNAME in "${DOCKERVOLS[@]}"; do      
         docker volume rm "$VOLNAME" >/dev/null
         echo "Destroyed docker volume ${VOLNAME}."
      done
   fi
   
   # remove launch script
   if [ -e "/usr/local/bin/${SERVICENAME}" ]; then 
      rm "/usr/local/bin/${SERVICENAME}"
   fi
   
   # delete service directoy.
   if [ -d "${ROOTPATH}/services/${SERVICENAME}" ]; then
      rm -r "${ROOTPATH}/services/${SERVICENAME}"
   fi
   
   echo "Service $SERVICENAME has been destroyed."
}



#------------------------------------------------------------------------------------

