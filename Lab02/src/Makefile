# C compiler
CC     =  icx
OPT3 	= -g -O3
OPTG0 	= -g -O0


CFLAGS  = -g -std=c99 -Wall
CFLAGSTAR  = -g -std=c99 -Wall
OPENMP	= -fopenmp
LFLAGS  = -lm

CINCL    = -I.
CLIBS    = -L. -lm

TAREADORCC = tar-clang
TAREADOR_FLAGS = -tareador-lite

TARGETS	= heat-seq heat-tareador heat-omp
all: $(TARGETS)
.PHONY:  heat-seq heat-tareador heat-omp

heat-seq: heat-seq.c solver-seq.c misc.c
	$(CC) $(CFLAGS) $(OPT3) $+ $(LFLAGS) -o $@

heat-tareador: heat-tareador.c solver-tareador.c misc.c
	@schroot -p -c tareador make heat_tareador_env

heat_tareador_env: heat-tareador.c solver-tareador.c misc.c
	$(TAREADORCC) $(TAREADOR_FLAGS) $(CFLAGSTAR) $(OPTG0) $+ $(CINCL) -o heat-tareador $(LFLAGS) $(CLIBS)

heat-omp: heat-omp.c solver-omp.c misc.c
	$(CC) $(CFLAGS) $(OPT3) $(OPENMP) $+ $(LFLAGS) -o $@

clean:
	rm -fr $(TARGETS) *.o .tareador_precomputed* *.log

ultraclean:
	rm -fr $(TARGETS) logs *.sh.o* *.sh.e* *.o *.ppm .tareador_precomputed* *.prv *.pcf *.row dependency_graph* *.times.txt *.ps *.txt *.log TRACE.* set-0 logs
