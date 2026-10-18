.SUFFIXES: .omp
#CC       = gcc-mp-4.6
CC       = gcc

OPENMP   = -fopenmp
CFLAGS   = -g -Wall -O3 $(OPENMP) -fno-inline -I.  
CLIBS    = 

TARGET  = 6.cancel 7.barrier
OBJECTS	= $(TARGET)

program:	$(TARGET)

.c.omp:
	$(CC) $< $(CFLAGS) -o $@ -I. -L. $(CLIBS) -lm

6.cancel: 6.cancel.c
	$(CC) $< $(CFLAGS) -o $@ -I. -L. $(CLIBS) -lm

7.barrier: 7.barrier.c
	$(CC) $< $(CFLAGS) -o $@ -I. -L. $(CLIBS) -lm

clean:
	rm -f $(OBJECTS)
