#--------------------------------------------------------
# makefile for the pical.c lab exercise
#--------------------------------------------------------

#--------------------------------------------------------
# Platform specific MPI compilers 
#--------------------------------------------------------

CC = mpicc

#--------------------------------------------------------
# The filename to be used for the executable
#--------------------------------------------------------

EXECUTABLE = pical pical_ld

all: $(EXECUTABLE)

#--------------------------------------------------------
# The source code to be compiled
#--------------------------------------------------------

SRC = pical.c 
SRCLD = pical_ld.c 
#SRC = pical.c pical_ld.c

#--------------------------------------------------------
# The compilation rules. Notice that 'TAB' symbol is used
#--------------------------------------------------------
#$(EXECUTABLE): $(SRC) 
#	$(CC) -o $@ $(SRC)

pical: pical.c
	$(CC) -o $@ $<

pical_ld: pical_ld.c
	$(CC) -o $@ $<

clean: 
	rm $(EXECUTABLE)
