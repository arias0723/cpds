#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <mpi.h>

typedef struct dbl_twoindex_struct {
    double val;
    int    rank;
    int    posn;
} dbl_twoindex;


void minloc_dbl_twoindex(void *in, void *inout, int *len, MPI_Datatype *type){
    /* ignore type, just trust that it's our dbl_twoindex type */
    dbl_twoindex *invals    = in;
    dbl_twoindex *inoutvals = inout;

    for (int i=0; i<*len; i++) {
        if (invals[i].val < inoutvals[i].val) {
            inoutvals[i].val  = invals[i].val;
            inoutvals[i].rank = invals[i].rank;
            inoutvals[i].posn = invals[i].posn;
        }
    }

    return;
}


int main(int argc, char **argv) {

    int rank, size;
    const int locn=5;
    double localarr[locn];

    dbl_twoindex local, global;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    /* create our new data type */
    MPI_Datatype mpi_dbl_twoindex;
    MPI_Datatype types[3] = { MPI_DOUBLE, MPI_INT, MPI_INT };
    MPI_Aint disps[3] = { offsetof(dbl_twoindex, val),
                     offsetof(dbl_twoindex, rank),
                     offsetof(dbl_twoindex, posn),  };
    int lens[3] = {1,1,1};
    MPI_Type_create_struct(3, lens, disps, types, &mpi_dbl_twoindex);
    MPI_Type_commit(&mpi_dbl_twoindex);

   /* create our operator */
    MPI_Op mpi_minloc_dbl_twoindex;
    MPI_Op_create(minloc_dbl_twoindex, 1, &mpi_minloc_dbl_twoindex);

    srand((rank+1)*time(NULL));
    for (int i=0; i<locn; i++)
        localarr[i] = 1.*rand()/RAND_MAX;

    for (int proc=0; proc<size; proc++) {
        if (rank == proc) {
            printf("Rank %2d has values: ",rank);
            for (int i=0; i<locn; i++)
                printf(" %8.4lf ", localarr[i]);
            printf("\n");
        }
        MPI_Barrier(MPI_COMM_WORLD);
    }

    local.val  = localarr[0];
    local.posn = 0;
    for (int i=1; i<locn; i++)
        if (localarr[i] < local.val) {
                local.val  = localarr[i];
                local.posn = i;
        }
    local.rank = rank;

    MPI_Allreduce(&local, &global, 1, mpi_dbl_twoindex, mpi_minloc_dbl_twoindex, MPI_COMM_WORLD);

    if (rank == 0) {
        printf("Rank %d has lowest value of %8.4lf in position %d.\n", global.rank, global.val, global.posn);
    }

    MPI_Op_free(&mpi_minloc_dbl_twoindex);
    MPI_Type_free(&mpi_dbl_twoindex);
    MPI_Finalize();

    return 0;
}
