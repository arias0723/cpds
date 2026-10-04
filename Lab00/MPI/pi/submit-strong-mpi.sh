#!/bin/bash

#SBATCH --job-name=submit-strong-mpi.sh
#SBATCH -D .
#SBATCH --output=submit-strong-mpi.sh.o%j
#SBATCH --error=submit-strong-mpi.sh.e%j
## #SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --distribution=block:cyclic # Distribute tasks cyclically across sockets

### cpu_bind does not work for current version installed in boada:
### SBATCH --cpu-bind=sockets          # Bind each task to a socket

SEQ=pi_seq
PROG=pi_mpi_collectives
size=1073741824
np_NMIN=1
np_NMAX=32
N=3

# Make sure that all binaries exist
make $SEQ
make $PROG

HOST=$(echo $HOSTNAME | cut -f 1 -d'.')

if [ ${HOST} = 'boada-11' ] || [ ${HOST} = 'boada-12' ] || [ ${HOST} == 'boada-13' ]
then
    echo "Use sbatch to execute this script"
    exit 0
fi

out=/tmp/out.$$	    # Temporal file where you save the execution results

outputpath=./elapsed.txt
outputpath2=./speedup.txt
rm -rf $outputpath 2> /dev/null
rm -rf $outputpath2 2> /dev/null

echo Executing $SEQ sequentially
min_elapsed=1000  # Minimo del elapsed time de las N ejecuciones del programa
i=0        # Variable contador de repeticiones
while (test $i -lt $N)
	do
		echo -n Run $i... 
		#./$SEQ $size > $out 2>/dev/null
		/usr/bin/time -f "%e" ./$SEQ $size > /dev/null 2> $out

		time=`cat $out|tail -n 1`
		echo Elapsed time = `cat $out`
			
                st=`echo "$time < $min_elapsed" | bc`
                if [ $st -eq 1 ]; then
                   min_elapsed=$time
                fi
			
		rm -f $out
		i=`expr $i + 1`
	done
echo -n ELAPSED TIME MIN OF $N EXECUTIONS =
sequential=`echo $min_elapsed`
echo $sequential
echo

echo "$PROG $size $np_NMIN $np_NMAX $N"

i=0
echo "Starting MPI executions..."

PARS=$np_NMIN
while (test $PARS -le $np_NMAX)
do
	echo Executing $PROG with $PARS MPI processes 
        min_elapsed=1000  # Minimo del elapsed time de las N ejecuciones del programa

	while (test $i -lt $N)
		do
			echo -n Run $i... 
			#mpirun.mpich -np $PARS -machinefile $TMPDIR/machines ./$PROG $size > $out 2>/dev/null
			mpirun.mpich -np $PARS ./$PROG $size > $out 2>/dev/null

			time=`cat $out|tail -n 1`
			echo Elapsed time = `cat $out`
			
                        st=`echo "$time < $min_elapsed" | bc`
                        if [ $st -eq 1 ]; then
                           min_elapsed=$time;
                        fi
			
			rm -f $out
			i=`expr $i + 1`
		done

	echo -n ELAPSED TIME MIN OF $N EXECUTIONS =

        min=`echo $min_elapsed`
    	result=`echo $sequential/$min|bc -l`
    	echo $min
	echo
	i=0

    	#output PARS i elapsed time minimo en fichero elapsed time
	echo -n $PARS >> $outputpath
	echo -n "   " >> $outputpath
    	echo $min >> $outputpath

    	#output PARS i speedup en fichero speedup
	echo -n $PARS >> $outputpath2
	echo -n "   " >> $outputpath2
    	echo $result >> $outputpath2

    	#incrementa el parametre
	PARS=`expr $PARS + 1`
done

#echo "Resultat de l'experiment (tambe es troben a " $outputpath " i " $outputpath2 " )"
echo "Results of the experiment (also found in files " $outputpath " and " $outputpath2 " )"
echo "#MPI processes Elapsed min"
cat $outputpath
echo
echo "#MPI processes Speedup"
cat $outputpath2
echo



USUARIO=`whoami`
FECHA=`date`
#jgraph -P strong-mpi.jgr >  $PROG-$size-$np_NMIN-$np_NMAX-$N-strong-mpi.ps
cp .strong-mpi.jgr strong-mpi-${HOST}.jgr
#sed -i -e "s/HHH/${HOST}/g" strong-mpi-${HOST}.jgr
sed -i -e "s/UUU/${USUARIO}/g" strong-mpi-${HOST}.jgr
sed -i -e "s/FFF/${FECHA}/g" strong-mpi-${HOST}.jgr
jgraph -P strong-mpi-${HOST}.jgr > $PROG-$size-$np_NMIN-$np_NMAX-$N-strong-mpi-${HOST}.ps
ps2pdf $PROG-$size-$np_NMIN-$np_NMAX-$N-strong-mpi-${HOST}.ps
rm strong-mpi-${HOST}.jgr
