/************************************************************************
 * Write an MPI "hello World!" program using the appropriate MPI calls.
 ************************************************************************/

/**************************
1.Include the header
**************************/
#include	<stdio.h>
#include	<string.h>
#include	<mpi.h>

void main(int argc, char *argv[])
{
  char message[20];
  MPI_Status status;
  int i,rank, size, tag=11;
  
  /**************************
   2.Initialize MPI
  **************************/
  MPI_Init(&argc, &argv);

  /**************************
  3.Find out my rank in the global communicator MPI_COMM_WORLD
  **************************/
  MPI_XXXX_XXXX(MPI_COMM_WORLD, &rank);

  /**************************
  4.Find out the size of the global communicator MPI_COMM_WORLD
  **************************/
  MPI_XXXX_XXXX(MPI_COMM_WORLD,&size);

  /**************************
  5.Check the rank, and
  **************************/

  if(XXXXXXXXX) {
    /**************************
      a.if the process is the master, then send a "Hello,World!"
        message, in characters, to each of the workers.
    **************************/
    strcpy(message, "Hello,World!");
    for (i=1; i<size; i++)
      MPI_XXXX(message, 13, XXXXXXXX, i, tag, XXXXXXXXXXXXXX);
  }                                                                                                                                
  else {                                                                                                                           
    /**************************                                                                                                    
      b.if the process is a worker, then receive the "Hello,World!"                                                                
        message and print it out.                                                                                                  
    **************************/                                                                                                    
    MPI_XXXX(XXXXXXX, 20, MPI_CHAR, X, XXX, XXXXXXXXXXXXXX, XXXXXXX);
    printf( "Process %d : %.13s\n", rank,message);                                                                                    
  }                                                                                                                                
                                                                                                                                   
  /**************************                                                                                                      
    6.Finalize MPI                                                                                                                 
  **************************/                                                                                                      
  MPI_XXXXXXXX();
}/* End Main */
