#include <stdio.h>
#include <stdlib.h>
#include <omp.h>	/* OpenMP */

/* Q1: Complete the parallelization of the program so that the */
/*     correct value for variable sum is returned in each      */
/*     printf statement. Note: in each part of the 3 parts of  */
/*     the program, all tasks generated should potentially     */
/*     execute in parallel.                                    */

#define SIZE 8192
#define BS   16
int X[SIZE], sum;

int main() 
{
    int i;

    for (i=0; i<SIZE; i++)
	X[i] = i;

    omp_set_num_threads(4);

    sum=0;
    #pragma omp parallel 
    #pragma omp single
    {
        // Part I
	#pragma omp taskgroup task_reduction(+: sum)
      	{
	    for (i=0; i< SIZE; i++)
		#pragma omp task firstprivate(i) in_reduction(+: sum)
	        sum += X[i];
	}

        printf("Value of sum after reduction in tasks = %d\n", sum);

    }


    sum=0;
    #pragma omp parallel reduction(task,+: sum)
    #pragma omp single
    {
        // Part I
	//#pragma omp taskgroup 
      	{
	    for (i=0; i< SIZE; i++)
		#pragma omp task firstprivate(i) in_reduction(+: sum)
	        sum += X[i];
	}
    }
    printf("Value of sum after reduction in parallel = %d\n", sum);

    sum=0;
    #pragma omp parallel 
    #pragma omp single
    {
        // Part II
	#pragma omp taskloop grainsize(BS) reduction(+: sum)
	for (i=0; i< SIZE; i++)
	    sum += X[i];

        printf("Value of sum after reduction in taskloop reduction = %d\n", sum);

    }


    sum=0;
    #pragma omp parallel reduction(task,+: sum)
    #pragma omp single
    {
        #pragma omp taskloop in_reduction(+: sum)
	for (i=0; i< SIZE; i++)
	        sum += X[i];
    }
    printf("Value of sum after reduction in parallel = %d\n", sum);


    /* However, the next one is incorrect. */
    sum=0;
    #pragma omp parallel reduction(+: sum)
    #pragma omp single
    {
        // Part II
	#pragma omp taskloop grainsize(BS) 
	for (i=0; i< SIZE; i++)
	    sum += X[i];
    }
    printf("Value of sum after reduction in parallel reduction plus taskloop = %d\n", sum);



    return 0;
}
