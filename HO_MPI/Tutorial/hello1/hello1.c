#include        <stdio.h>
#include        <mpi.h>

int main(int argc, char *argv[])
{
  int rank;

  /* Initialize MPI */
  MPI_Init(&argc, &argv);
  
  /* Find out my rank in the global communicator MPI_COMM_WORLD*/
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  /* Insert code to do conditional work if my rank is 0 */
  if(rank == 0){
    printf("Hello, World!!! (from masternode)\n");

  } else{

  /* Insert code to print the output message "Hello, World!"*/
  printf("Hello, World! (from worker node)\n");

  }
  /* Exit and finalize MPI */
  MPI_Finalize();

}/* End Main */
