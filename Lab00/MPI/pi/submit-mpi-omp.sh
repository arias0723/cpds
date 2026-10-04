#!/bin/bash

#SBATCH --job-name=submit-mpi-omp.sh
#SBATCH -D .
#SBATCH --output=submit-mpi-omp.sh.o%j
#SBATCH --error=submit-mpi-omp.sh.e%j
#SBATCH --partition=execution
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=32

PROGRAM=pi_mpi_omp
size=1073741824

# Make sure that all binaries exist
make $PROGRAM 2>&1
if [[ $? -ne 0 ]]; then
    echo "Abort: Compilation error, parallel version"
    exit 0
fi

HOST=$(echo $HOSTNAME | cut -f 1 -d'.')

if [ ${HOST} = 'boada-11' ] || [ ${HOST} = 'boada-12' ] || [ ${HOST} == 'boada-13' ]
then
    echo "Use sbatch to execute this script"
    exit 0
fi


for mpi_i in `seq 1 2`;
do
  export MPI_PROCESSES=$mpi_i
  for i in `seq 1 2`;
  do
    echo "Executing... mpi: $mpi_i processes. Number of threads per process:" $i
    export OMP_NUM_THREADS=$i
    mpirun.mpich -np ${MPI_PROCESSES}  ./$PROGRAM $size
    #mpirun.mpich -np ${MPI_PROCESSES}  -machinefile $TMPDIR/machines ./$PROGRAM $size
  done   
done

