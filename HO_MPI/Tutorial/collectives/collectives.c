#include <mpi.h>
#include <math.h>
#include <stdio.h>

void main(argc,argv)
int argc;
char *argv[];
{
  int p, i, Iam, root;
  int counts[4] = {1, 2, 3, 4};
  int displs[4] = {0, 1, 3, 6};
  char x[10], y[10], a, alphabet;

   /*----------------*/
  /* initialize MPI */
 /*----------------*/

   MPI_Init(&argc,&argv);

   /*---------------------------*/
  /* get the process ID number */                                                                                                  
 /*---------------------------*/

   MPI_Comm_rank(MPI_COMM_WORLD, &Iam);

   /*-----------------------------------*/
  /* get the size of the process group */
 /*-----------------------------------*/

   MPI_Comm_size(MPI_COMM_WORLD, &p);

  root = 1;
  if (Iam == 0) {
    printf("  Function      Proc  Sendbuf          Recvbuf\n");
    printf("  --------      ----  -------          -------\n");
  }

  MPI_Barrier(MPI_COMM_WORLD);

  for (i=0; i<p; i++) {
    x[i] = ' ';
  }

  alphabet = 'a';

   /*-----------------------------------*/
  /* MPI_Gather()                      */
 /*-----------------------------------*/

  x[0] = alphabet+Iam;
  for (i=0; i<p; i++) {
        y[i] = ' ';
  }
  MPI_Gather(x,1,MPI_CHAR,          /* send buf,count,type */
             y,1,MPI_CHAR,          /* recv buf,count,type */
             root,                  /* root (data origin)  */
             MPI_COMM_WORLD);       /* comm                */

  printf(" MPI_Gather    :  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  for (i=0; i<p; i++) {
    printf("  %c",y[i]);
  }
  printf("\n");

  MPI_Barrier(MPI_COMM_WORLD);

   /*-----------------------------------*/
  /* MPI_Gatherv()                     */
 /*-----------------------------------*/

  for (i=0; i<10; i++) {
    x[i] = ' ';
    y[i] = ' ';
  }
  for (i=0; i<counts[Iam]; i++) {
    x[i] = alphabet+displs[Iam]+i;
  }

  MPI_Gatherv(x,counts[Iam],MPI_CHAR, /* send buf,count,type  */
              y,counts,               /* recv buf,count array */
              displs, MPI_CHAR,       /* displacements,type   */
              root,                   /* root (data origin)  */
              MPI_COMM_WORLD);        /* comm                */

  printf(" MPI_Gatherv   :  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  for (i=0; i<10; i++) {
    printf("  %c",y[i]);
  }                                                                                                                                
  printf("\n");                                                                                                                    
                                                                                                                                   
  MPI_Barrier(MPI_COMM_WORLD);

   /*-----------------------------------*/
  /* MPI_Allgather()                   */
 /*-----------------------------------*/

  x[0] = alphabet+Iam;

  for (i=0; i<p; i++) {
    y[i] = ' ';
  }
  MPI_Allgather(x,1,MPI_CHAR,     /* send buf,count,type */
                y,1,MPI_CHAR,     /* recv buf,count,type */
                MPI_COMM_WORLD);  /* comm                */

  printf(" MPI_Allgather :  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  for (i=0; i<p; i++) {
    printf("  %c",y[i]);
  }
  printf("\n");

  MPI_Barrier(MPI_COMM_WORLD);

   /*-----------------------------------*/
  /* MPI_Allgatherv()                  */
 /*-----------------------------------*/

  for (i=0; i<10; i++) {
    x[i] = ' ';
    y[i] = ' ';
  }
  for (i=0; i<counts[Iam]; i++) {
    x[i] = alphabet+displs[Iam]+i;
  }

  MPI_Allgatherv(x,counts[Iam],MPI_CHAR, /* send buf,count,type  */
                 y,counts,               /* recv buf,count array */
                 displs, MPI_CHAR,       /* displacements,type   */
                 MPI_COMM_WORLD);        /* comm                */

  printf(" MPI_Allgatherv:  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  for (i=0; i<10; i++) {                                                                                                           
    printf("  %c",y[i]);                                                                                                           
  }                                                                                                                                
  printf("\n");                                                                                                                    
                                                                                                                                   
  MPI_Barrier(MPI_COMM_WORLD);           

   /*-----------------------------------*/
  /* MPI_Scatter()                     */
 /*-----------------------------------*/

  for (i=0; i<p; i++) {
    x[i] = alphabet+i+Iam*p;
    y[i] = ' ';
  }
  MPI_Scatter(x,1,MPI_CHAR,      /* send buf,count,type */
              y,1,MPI_CHAR,      /* recv buf,count,type */
              root,              /* root (data origin)  */
              MPI_COMM_WORLD);   /* comm                */

  printf(" MPI_Scatter   :  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  for (i=0; i<p; i++) {
    printf("  %c",y[i]);
  }
  printf("\n");

  MPI_Barrier(MPI_COMM_WORLD);

   /*-----------------------------------*/
  /* MPI_Alltoall()                    */
 /*-----------------------------------*/

  for (i=0; i<p;i++) {
    x[i] = alphabet+i+Iam*p;
    y[i] = ' ';
  }

  MPI_Alltoall(x,1,MPI_CHAR,       /* send buf,count,type */
               y,1,MPI_CHAR,       /* recv buf,count,type */
               MPI_COMM_WORLD);    /* comm,flag           */

  printf(" MPI_Alltoall  :  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  for (i=0; i<p; i++) {
    printf("  %c",y[i]);
  }
  printf("\n");

  MPI_Barrier(MPI_COMM_WORLD);

   /*-----------------------------------*/
  /* MPI_Reduce()                      */
 /*-----------------------------------*/

  for (i=0; i<p; i++) {
    x[i] = alphabet+i+Iam*p;
    y[i] = ' ';
  }
  MPI_Reduce(x, y,            /* send buf, recv buf  */
             p, MPI_CHAR,     /* count,type          */
             MPI_MAX,         /* operation           */
             root,            /* root (data origin)  */
             MPI_COMM_WORLD); /* comm                */

  printf(" MPI_Reduce MAX:  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  for (i=0; i<p; i++) {
    printf("  %c",y[i]);
  }
  printf("\n");

  MPI_Barrier(MPI_COMM_WORLD);

   /*-----------------------------------*/
  /* MPI_Allreduce()                   */
 /*-----------------------------------*/

  for (i=0; i<p; i++) {
    x[i] = alphabet+i+Iam*p;
    y[i] = ' ';
  }
  MPI_Allreduce(x, y,         /* send buf, recv buf  */
             p, MPI_CHAR,     /* count,type          */
             MPI_MAX,         /* operation           */
             MPI_COMM_WORLD); /* comm                */

  printf(" MPI_Allreduce :  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  for (i=0; i<p; i++) {
    printf("  %c",y[i]);
  }
  printf("\n");

  MPI_Barrier(MPI_COMM_WORLD);

   /*-----------------------------------*/
  /* MPI_Bcast()                       */
 /*-----------------------------------*/

  a = ' ';
  for (i=0; i<p; i++) {
    x[i] = ' ';
    y[i] = ' ';
  }
  if(Iam == root) {
    a = 'b';
    x[0] = a;
  }
  MPI_Bcast(&a,1,MPI_CHAR,          /* buf,count,type */
            root,MPI_COMM_WORLD);   /* root,comm      */

  printf(" MPI_Bcast     :  %d ", Iam);
  for (i=0; i<p; i++) {
    printf("  %c",x[i]);
  }
  printf("     ");
  printf("  %c",a);
  printf("\n");

  MPI_Barrier(MPI_COMM_WORLD);

   /*--------------*/
  /* Finalize MPI */
 /*--------------*/

  MPI_Finalize();

}
