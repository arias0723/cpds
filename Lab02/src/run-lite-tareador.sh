#!/bin/bash
#rm -rf .tareador_precomputed_*

filename=$1
shift
options=$@
echo "filename:$filename"
echo "options:$options"

source /Soft/PAR/environment.bash
rm -rf .tareador_precomputed_$filename

export LD_PRELOAD_TMP=$LD_PRELOAD
export PARAVER_HOME=$SOFT_ROOT/paraver/4.11.2/
export PATH_OLD=$PATH
export PATH=$PARAVER_HOME/bin:/usr/bin/:$PATH_OLD
echo "Removing LD_PRELOAD"
export -n LD_PRELOAD
echo "Calling tareador"
/usr/bin/python $TAREADOR_GUI_ROOT/xdot/tareador_gui.py --llvm --lite $filename -b "test.dat -n 4 -s 32 -a $options" >& .output.tareador.execution.txt
#tareador_gui.py --llvm --lite $filename -b "test.dat -n 4 -s 32 -a $options"
export LD_PRELOAD=$LD_PRELOAD_TMP
export PARAVER_HOME=$SOFT_ROOT/paraver/4.12.0/
export PATH=$PATH_OLD
echo "Exporting again LD_PRELOAD"
