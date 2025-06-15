#include <stdio.h>
#include "meuAlocador.h"

int main (long int argc, char** argv) {
  void *a,*b,*c,*d,*e;

  iniciaAlocador(); 
  imprimeMapa();
  // 0) estado inicial

  a=(void *) alocaMem(10);
  imprimeMapa();
  b=(void *) alocaMem(13);
  imprimeMapa();
  c=(void *) alocaMem(12);
  imprimeMapa();
  d=(void *) alocaMem(11);
  imprimeMapa();
  // 1) Espero ver quatro segmentos ocupados

  liberaMem(b);
  imprimeMapa(); 
  liberaMem(d);
  imprimeMapa(); 
  // 2) Espero ver quatro segmentos alternando
  //    ocupados e livres

  b=(void *) alocaMem(5);
  imprimeMapa();
  d=(void *) alocaMem(9);
  imprimeMapa();
  e=(void *) alocaMem(4);
  imprimeMapa();
  // 3) Deduzam
	
  liberaMem(c);
  imprimeMapa(); 
  liberaMem(a);
  imprimeMapa();
  liberaMem(b);
  imprimeMapa();
  liberaMem(d);
  imprimeMapa();
  liberaMem(e);
  imprimeMapa();
   // 4) volta ao estado inicial

  finalizaAlocador();
}
