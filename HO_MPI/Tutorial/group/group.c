#include "mpi.h"
#include <stdio.h>
#include <stdlib.h>

#define NPROCS 12

int main(argc,argv)
int argc;
char *argv[];

{

  int rank, new_rank, sendbuf, recvbuf, numtasks;
  int ranks1[6]={0,1,2,3,4,5}, ranks2[6]={6,7,8,9,10,11};
  MPI_Group  orig_group, new_group;
  MPI_Comm   new_comm;

   /*----------------*/
  /* Initialize MPI */
 /*----------------*/

  MPI_Init(&argc,&argv);

   /*------------------------------------------------------*/
  /* Get my rank in the MPI_COMM_WORLD communicator group */
 /*------------------------------------------------------*/

  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

   /*-------------------------------------------------------*/                                                                     
  /* Get the size of the MPI_COMM_WORLD communicator group */
 /*-------------------------------------------------------*/

  MPI_Comm_size(MPI_COMM_WORLD, &numtasks);

  if (numtasks != NPROCS) {
    printf("Must specify MP_PROCS= %d. Terminating.\n",NPROCS);
    MPI_Finalize();
    exit(0);
  }

  sendbuf = rank;

   /*-----------------------------------*/                                                                     
  /* Extract the original group handle */
 /*-----------------------------------*/

  MPI_Comm_group(MPI_COMM_WORLD, &orig_group);

   /*-------------------------------------------------------*/                                                                     
  /* Divide tasks into two distinct groups based upon rank */
 /*-------------------------------------------------------*/

  if (rank < NPROCS/2)
    MPI_Group_incl(orig_group, NPROCS/2, ranks1, &new_group);
  else
    MPI_Group_incl(orig_group, NPROCS/2, ranks2, &new_group);

   /*------------------------------------------------------------------------*/                                                                     
  /* Create new new communicator and then perform collective communications */
 /*------------------------------------------------------------------------*/

  MPI_Comm_create(MPI_COMM_WORLD, new_group, &new_comm);
  MPI_Allreduce(&sendbuf, &recvbuf, 1, MPI_INT, MPI_SUM, new_comm);


   /*-----------------------------------------------------*/
  /* Get my rank in the new new_group communicator group */
 /*-----------------------------------------------------*/

  MPI_Group_rank (new_group, &new_rank);

  printf("rank= %d newrank= %d recvbuf= %d\n",rank,new_rank,recvbuf);

   /*--------------*/
  /* Finalize MPI */
 /*--------------*/

  MPI_Finalize();
}
