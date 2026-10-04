#!/bin/bash

#SBATCH --job-name=submit-weak-mpi.sh
#SBATCH -D .
#SBATCH --output=submit-weak-mpi.sh.o%j
#SBATCH --error=submit-weak-mpi.sh.e%j
#SBATCH --partition=execution
#SBATCH --nodes=3
#SBATCH --ntasks=3
#SBATCH --cpus-per-task=1

PROG=pi_mpi_collectives
size=134217728
np_NMIN=1
np_NMAX=3
N=3

# Make sure that all binaries exist
make $PROG 2>&1
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


out=/tmp/out.$$	    # Temporal file where you save the execution results

outputpath=./executiontime.txt
outputpath2=./efficiency.txt
rm -rf $outputpath 2> /dev/null
rm -rf $outputpath2 2> /dev/null

echo Executing $PROG with one MPI process 
min_elapsed=1000  # Minimo del elapsed time de las N ejecuciones del programa
i=0        # Variable contador de repeticiones
while (test $i -lt $N)
	do
		echo -n Run $i... 
		#mpirun.mpich -np 1 -machinefile $TMPDIR/machines ./$PROG $size > $out 2>/dev/null
		mpirun.mpich -np 1 ./$PROG $size > $out 2>/dev/null

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
baseline=`echo $min_elapsed`
echo $baseline
echo

echo "$PROG $size $np_NMIN $np_NMAX $N"

i=0
echo "Starting MPI executions..."

PARS=$np_NMIN
while (test $PARS -le $np_NMAX)
do
	echo Executing $PROG with $PARS mpi process 
        min_elapsed=1000  # Minimo del elapsed time de las N ejecuciones del programa
	DSIZE=`expr $DSIZE + $size`

	while (test $i -lt $N)
		do
			echo -n Run $i with size $DSIZE ... 
			#mpirun.mpich -np $PARS -machinefile $TMPDIR/machines ./$PROG $DSIZE > $out 2>/dev/null
			mpirun.mpich -np $PARS ./$PROG $DSIZE > $out 2>/dev/null

			time=`cat $out|tail -n 1`
			echo Elapsed time = `cat $out`
			
                        st=`echo "$time < $min_elapsed" | bc`
                        if [ $st -eq 1 ]; then
                           min_elapsed=$time;
                        fi
			
			rm -f $out
			i=`expr $i + 1`
		done

	echo -n ELAPSED TIME Min OF $N EXECUTIONS =

        min=`echo $min_elapsed`
    	result=`echo $baseline/$min|bc -l`
    	echo $min
	echo
	i=0

    	#output PARS i elapsed time minimo en fichero elapsed time
	echo -n $PARS >> $outputpath
	echo -n "   " >> $outputpath
    	echo $min >> $outputpath

    	#output PARS i Parallel-Efficiency en fichero efficiency
	echo -n $PARS >> $outputpath2
	echo -n "   " >> $outputpath2
    	echo $result >> $outputpath2

    	#incrementa el parametre
	PARS=`expr $PARS + 1`
done

echo "Result of the experiment (also available in  " $outputpath " and " $outputpath2 " )"
echo "#mpi process Elapsed min"
cat $outputpath
echo
echo "#mpi process Parallel-Efficiency"
cat $outputpath2
echo

jgraph -P .weak-mpi.jgr >  $PROG-$size-$np_NMIN-$np_NMAX-$N-weak-mpi.ps
ps2pdf $PROG-$size-$np_NMIN-$np_NMAX-$N-weak-mpi.ps
rm $PROG-$size-$np_NMIN-$np_NMAX-$N-weak-mpi.ps
