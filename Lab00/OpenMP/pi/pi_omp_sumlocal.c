/*
 * Compute pi by approximating the area under the curve f(x) = 4 / (1 + x*x)
 * between 0 and 1.
 *
 * Parallel version using OpenMP
 */
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <omp.h>	/* OpenMP */

double getusec_() {
        struct timeval time;
        gettimeofday(&time, NULL);
        return ((double)time.tv_sec * (double)1e6 + (double)time.tv_usec);
}

#define START_COUNT_TIME stamp = getusec_();
#define STOP_COUNT_TIME(_m) stamp = getusec_() - stamp;\
                        stamp = stamp/1e6;\
                        printf ("%s%0.6f\n",(_m), stamp);

int main(int argc, char *argv[]) {
    double stamp;
    START_COUNT_TIME;

    double x, sum=0.0, pi=0.0;
    double step;

    const char Usage[] = "Usage: pi <num_steps> (try 1000000000)\n";
    if (argc < 2) {
	fprintf(stderr, Usage);
	exit(1);
    }
    long int num_steps = atol(argv[1]);
    step = 1.0/(double) num_steps;

    /* do computation -- using all available threads */
    double sumlocal = 0.0;
    #pragma omp parallel private(x) firstprivate(sumlocal)
    {
        #pragma omp for 
        for (long int i=0; i<num_steps; ++i) {
            x = (i+0.5)*step;
            sumlocal += 4.0/(1.0+x*x);
        }
        // #pragma omp critical 
        #pragma omp atomic 
	sum += sumlocal;
    }
    pi = step * sum;

    /* print results */
    printf("Number pi after %ld iterations = %.15f\n", num_steps, pi);

    //STOP_COUNT_TIME("");
    STOP_COUNT_TIME("Execution time (secs.): ");

    return EXIT_SUCCESS;
}
