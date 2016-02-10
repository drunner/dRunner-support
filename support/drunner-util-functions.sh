#!/bin/bash

#-----------------------------------------------------------------------------------------------------------------------------

# print an error message.
function errecho {
   echo " ">&2 ; echo -e "\e[31m\e[1m${1}\e[0m">&2  ; echo " ">&2
   ERRORFREE=1
}

# die MESSAGE 
# colourful way to die.
function die {
   local DIEMSG="${1:-"Unexpected error and we died with no message."}"
   local DIERVAL="${2:-1}"
   [ "$DIERVAL" -ne 0 ] || { echo " ">&2 ; echo -e "$DIEMSG">&2 ; echo " ">&2 ; }
   [ "$DIERVAL" -eq 0 ] || errecho "$DIEMSG"
   exit $DIERVAL
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
   if [ ! -e "${ROOTPATH}/support/run_on_service/validator-image" ]; then
      die "Missing dRunner file: ${ROOTPATH}/support/run_on_service/validator-image"
   fi
   
   # need to get validator-image into the container and run it with the containers UID (non-root)
   docker run --rm -v "${ROOTPATH}/support/run_on_service:/support" "${IMAGENAME}" "/support/validator-image"
   [ "$?" -eq 0 ] || die "${IMAGENAME} is not dRunner compatible."
   echo "${IMAGENAME} is dRunner compatible."
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

# silentSource SOURCEFILE
function silentSource {
   if [ -e "$1" ]; then
      source "$1" || echo "Error sourcing ${1}... corrupt?"
   fi
}

#------------------------------------------------------------------------------------

# loadServiceSilent
# Requires SERVICENAME and ROOTPATH, but copes with anything else.
function loadServiceSilent {   
   if [ ! -v SERVICENAME ] || [ -z "$SERVICENAME" ]; then die "Can't load service because SERVICENAME is not set." ; fi
   if [ ! -v ROOTPATH ] || [ ! -d "$ROOTPATH" ]; then die "Can't load service because ROOTPATH doesn't exist." ; fi

   silentSource "${ROOTPATH}/services/${SERVICENAME}/drunner/servicecfg.sh"
   silentSource "${ROOTPATH}/services/${SERVICENAME}/imagename.sh"
   
   if [ -v VOLUMES ]; then
      for i in "${!VOLUMES[@]}"; do
         DOCKERVOLS[$((i))]="drunner-${SERVICENAME}-${VOLUMES[i]//[![:alnum:]]/}"
         DOCKEROPTS[$((2*i))]="-v"
         DOCKEROPTS[$((2*i+1))]="${DOCKERVOLS[i]}:${VOLUMES[i]}"
      done
   fi
}

#------------------------------------------------------------------------------------

# validateLoadService
# Validate the service is fully okay, then load it.
function validateLoadService {
   if [ ! -v SERVICENAME ] || [ -z "$SERVICENAME" ]; then die "validateLoadService - SERVICENAME not defined." ; fi
   "${ROOTPATH}/support/validator-service" "$SERVICENAME" || exit 1
   
   loadServiceSilent
}

#------------------------------------------------------------------------------------

# destroys everything we can about a service, except the Docker volumes.
# requires both SERVICENAME and ROOTPATH to be set. Assumes nothing else.
function destroyService_low {
   # call destroy in service.
   if [ ! -v SERVICENAME ] || [ -z "$SERVICENAME" ]; then die "Can't destroy because SERVICENAME is not set." ; fi
   
   # attempt to read the service info, if present.
   loadServiceSilent
      
   # remove launch script
   if [ -e "/usr/local/bin/${SERVICENAME}" ]; then 
      rm "/usr/local/bin/${SERVICENAME}" || errecho "Couldn't remove launch script: /usr/local/bin/${SERVICENAME}"
   fi
   
   # delete service directoy.
   if [ -d "${ROOTPATH}/services/${SERVICENAME}" ]; then
      rm -r "${ROOTPATH}/services/${SERVICENAME}" || errecho "Couldn't remove service tree: ${ROOTPATH}/services/${SERVICENAME}"
   fi
}

#------------------------------------------------------------------------------------

# uninstall the service.
function uninstallService {
   ERRORFREE=0
   
   # important to call this first (e.g. to stop services)
   if [ -e "${ROOTPATH}/services/${SERVICENAME}/drunner/servicerunner" ]; then 
      "${ROOTPATH}/services/${SERVICENAME}/drunner/servicerunner" uninstall || errecho "Calling servicerunner uninstall failed."
   fi

   destroyService_low

   return "$ERRORFREE"
}

#------------------------------------------------------------------------------------


# destroy the Docker service, including all data and configuration volumes
function obliterateService { 
   ERRORFREE=0
   
   # important to call this first (e.g. to stop services)
   if [ -e "${ROOTPATH}/services/${SERVICENAME}/drunner/servicerunner" ]; then 
      "${ROOTPATH}/services/${SERVICENAME}/drunner/servicerunner" obliterate || errecho "Calling servicerunner obliterate failed."
   fi

   destroyService_low
       
   # remove volume containers.
   if [ -v DOCKERVOLS ]; then
      for VOLNAME in "${DOCKERVOLS[@]}"; do      
         docker volume rm "$VOLNAME" >/dev/null
         echo "Destroyed docker volume ${VOLNAME}."
      done
   fi
   
   return "$ERRORFREE"
}



#------------------------------------------------------------------------------------

