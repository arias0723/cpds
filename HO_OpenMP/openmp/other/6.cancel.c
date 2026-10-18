#include <unistd.h> // For execv
#include <stdlib.h> // For putenv
#include <stdio.h>  // For printf
#include <omp.h>    // For omp_get_cancellation, omp_get_thread_num()


#define DBsize 1024
#define key    10

int main(int argc, char** argv) {
	unsigned long position, i;
	double * DB;

        if(!omp_get_cancellation())
           {
           printf("Cancellations were not enabled, enabling cancellation and rerunning program\n");
           putenv("OMP_CANCELLATION=true");
           execv(argv[0], argv);
           }

	DB = (double *) malloc(sizeof(double) * DBsize);
	// initialize elements in DB
        for (i = 0; i < DBsize; i++) DB[i]=0.25;
 	DB[255]=key; DB[300]=key; DB[600]=key;

	position = DBsize;

	#pragma omp parallel 
        #pragma omp for schedule(static, 1)
	for (i = 0; i < DBsize; i++) {
	//for (i = 0; (i < DBsize) && (position == DBsize); i++)
		printf("Thread %d executing iteration %ld\n", omp_get_thread_num(), i);
		if (i > position) {
			;
			#pragma omp cancellation point for
		}
		if (DB[i] == key) {
			if (i < position) position = i;
			printf("Thread %d found key in position %ld\n", omp_get_thread_num(), i);
			#pragma omp cancel for
		}
	}

        printf("Key found in position %ld\n", position);
}
