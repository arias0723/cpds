/* C Example */
#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>
#include <omp.h>

/* header files for getting hostname and process id */
#include <unistd.h>
#include <sys/types.h>

/* Mirem els limits */
#include <sys/time.h>
#include <sys/resource.h>


//#include "constants.h"

#ifndef _COLLECTIVES_
  #define _COLLECTIVES_ 0
#else
  #define _COLLECTIVES_ 1
#endif 

#if _EXTRAE_
#include "extrae_user_events.h"
// Extrae Constants
#define  PROGRAM    1000
#define  END        0
#define  SERIAL     1
#define  PARALLEL   2
#define  REST_MAIN  3
#else 
double getusec_() {
        struct timeval time;
        gettimeofday(&time, NULL);
        return ((double)time.tv_sec * (double)1e6 + (double)time.tv_usec);
}


#define START_COUNT_TIME stamp = getusec_();
#define STOP_COUNT_TIME(_m) stamp = getusec_() - stamp;\
                        stamp = stamp/1e6;\
                        printf ("%s%0.6f\n",(_m), stamp);
#endif

inline float my_rand(unsigned long long int *seed) { 
       unsigned long long int a = 16807;  // constants for random number generator 
       unsigned long long int m = 2147483647;   // 2^31 - 1 
       unsigned long long int x = (unsigned long long int ) *seed; 
       x = (a * x)%m; 
       *seed = (unsigned long long int) x; 
       return ((float)x)/m; 
} 

int main(int argc, char *argv[]) {
    int  myid, numprocs; 
#ifdef _DEBUG_ 
    char hostname[128];
#endif
    float pi=0.0;
    float x, y;
    unsigned long long int points_in_circle=0, i;
    unsigned long long int all_points_in_circle=0;

#if !_COLLECTIVES_
    MPI_Status status;
#endif

    MPI_Init(&argc, &argv); 
    MPI_Comm_size(MPI_COMM_WORLD, &numprocs); 
    MPI_Comm_rank(MPI_COMM_WORLD, &myid); 

    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len;
    MPI_Get_processor_name(processor_name, &name_len);
    printf("Execution on node %s, rank %d" " out of %d processors\n",
           processor_name, myid, numprocs);

#if _EXTRAE_
    Extrae_event (PROGRAM, SERIAL);
#else
    double stamp=0.0;
    if (myid == 0) 
       START_COUNT_TIME;
#endif

#if _EXTRAE_
    Extrae_event (PROGRAM, REST_MAIN);
#endif

    const char Usage[] = "Usage: pi <trials> (try 1000000000)\n";
    if (argc < 2) {
	fprintf(stderr, Usage);
	exit(1);
    }
    unsigned long long int trials = atoll(argv[1]);

#if _EXTRAE_
    Extrae_event (PROGRAM, END);
#endif

    /* do computation -- using all available threads */
#if _EXTRAE_
    Extrae_event (PROGRAM, PARALLEL);
#endif

     #pragma omp parallel
     {
       int num_threads= omp_get_num_threads();
       unsigned long long int seed = myid*num_threads+omp_get_thread_num()+1;
       #pragma omp for private(x,y) reduction(+:points_in_circle)
       for(i = myid; i < trials; i+=numprocs) {
	x = my_rand(&seed);
	y = my_rand(&seed);
	points_in_circle += (x*x + y*y <= 1.0f);
       }
     }
#if _EXTRAE_
    Extrae_event (PROGRAM, END);
    Extrae_event (PROGRAM, SERIAL);
#endif

    /* master collects all partial sums */
#if _COLLECTIVES_
    MPI_Reduce(&points_in_circle, &all_points_in_circle, 1, MPI_UNSIGNED_LONG_LONG, MPI_SUM, 0, MPI_COMM_WORLD); 
#else
    if (myid == 0) {
            all_points_in_circle = points_in_circle;
            for (i=1; i<numprocs; i++) {
                    MPI_Recv(&points_in_circle, 1, MPI_UNSIGNED_LONG_LONG, i, 0, MPI_COMM_WORLD, &status);
                    all_points_in_circle += points_in_circle;
            }
    }
    else 
            MPI_Send(&points_in_circle, 1, MPI_UNSIGNED_LONG_LONG, 0, 0, MPI_COMM_WORLD);
#endif

    if (myid == 0) {
      pi = 4.0f * all_points_in_circle / trials;
     /* print results */
      printf("Number pi after %lld iterations = %.15f\n", trials, pi);
    }

#if _EXTRAE_
    Extrae_event (PROGRAM, END);
#else
   
#ifdef _DEBUG_ 
    gethostname(hostname, 126);
    printf( "Hello world from process %d of %d at hostname %s\n",myid, numprocs, hostname );
#endif

    if (myid == 0) 
    {
       STOP_COUNT_TIME("");
    }
#endif
    MPI_Finalize(); 

    return EXIT_SUCCESS;
}
