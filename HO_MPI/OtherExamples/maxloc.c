#include <stdio.h>
#include <stdlib.h>
#include<time.h>
#include <mpi.h>

int main(int argc, char **argv) {

    int rank, size;
    const int locn=5;
    int localarr[locn];
    char optimal[10]="largest";
    //char optimal[10]="lowest";

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    srand((rank+1)*time(NULL));
    for (int i=0; i<locn; i++) 
        localarr[i] = rand() % 100;

    for (int proc=0; proc<size; proc++) {
        if (rank == proc) {
            printf("Rank %2d has values: ",rank);
            for (int i=0; i<locn; i++)
                printf(" %d ", localarr[i]);
            printf("\n");
        }
        MPI_Barrier(MPI_COMM_WORLD);
    }

    int localres[2];
    int globalres[2];
    localres[0] = localarr[0];
    for (int i=1; i<locn; i++) 
        if (localarr[i] > localres[0]) localres[0] = localarr[i];
        /* This could be changed easily in order to get the minimum :
        if (localarr[i] < localres[0]) localres[0] = localarr[i];
        */

    localres[1] = rank;

    MPI_Allreduce(localres, globalres, 1, MPI_2INT, MPI_MAXLOC, MPI_COMM_WORLD);
    /* This could be changed easily in order to get the minimum & its location:
    MPI_Allreduce(localres, globalres, 1, MPI_2INT, MPI_MINLOC, MPI_COMM_WORLD);
    */

    if (rank == 0) {
        printf("Rank %d has %s value of %d\n",
               globalres[1], optimal, globalres[0]);
    }

    MPI_Finalize();

    return 0;
}
