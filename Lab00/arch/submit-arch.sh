#!/bin/bash

#SBATCH --job-name=submit-arch.sh
# following option makes sure the job will run in the current directory
#SBATCH -D .
#SBATCH --output=submit-arch.sh.o%j
#SBATCH --error=submit-arch.sh.e%j

HOST=$(echo $HOSTNAME | cut -f 1 -d'.')

PROG=lscpu
$PROG > ${PROG}-${HOST}

PROG='lstopo'
$PROG > ${PROG}-${HOST}
PROGFIG='lstopo --of fig map.fig'
$PROGFIG 
mv map.fig map-${HOST}.fig
fig2dev -L pdf map-${HOST}.fig map-${HOST}.pdf


PROG='numactl'
echo "Retrieving the NUMA topology within ${HOST}:" > ${PROG}-${HOST}
$PROG --hardware >> ${PROG}-${HOST}
