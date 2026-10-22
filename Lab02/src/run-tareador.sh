USAGE="\n USAGE: ./run_tareador.sh prog \n
        prog        -> Tareador program name\n
        solver      -> 0: Jacobi; 1: Gauss-Seidel\n"

if (test $# -lt 2 || test $# -gt 2)
then
        echo -e $USAGE
        exit 0
fi

make $1 2>&1
if [[ $? -ne 0 ]]; then
    echo "Abort: Compilation Error"
    exit 0
fi

rm -rf .tareador_precomputed_$1
filename=$1
shift
rm $filename
make $filename
options=$@
schroot -p -c tareador bash run-lite-tareador.sh -- $filename "$options"
