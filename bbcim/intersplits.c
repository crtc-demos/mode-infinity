/*
//intersplit.c: maak of splits om-en-om diskbeeld, SINGLE/DOUBLE DENSITY
//interss & splitds
//Copyright (C) W.H.Scholten 1996
//11-3-1996
//Deel van bbcim.
*/


void interss(int argc, char *argv[], int options) {
  char  side0[50],  side1[50], interleaved[50]; 
  char option2[5];
  unsigned char byte;
  FILE *fp0, *fp1, *fp_inter;
  int sec_per_track, track, i;

  int dd=0;

  if ((argc-options)==1) {
    #ifdef NL
    printf("Single density (sd) of double density (dd)?");
    #else
    printf("Single density (sd) or double density (dd)?");
    #endif
    scanf("%2s", option2);
  } else {strcpy(option2, argv[1+options]); options++;}

  if (!strcmp(option2, "dd")) dd=1;


  if ((argc-options)==1) {
    #ifdef NL
    printf("Naam van het diskbeeld voor zijde 0?");
    #else
    printf("Name of the disk image for side 0?");
    #endif
    scanf("%50s", side0);
  } else strcpy(side0, argv[1+options]);


  if ((argc-options)<=2) {
    #ifdef NL
    printf("Naam van het diskbeeld voor zijde 1?");
    #else
    printf("Name of the disk image for side 1?");
    #endif
    scanf("%50s", side1);
  } else strcpy(side1, argv[2+options]);


  if ((argc-options)<=3) {
    #ifdef NL
    printf("Naam van om-en-om beeld?");
    #else
    printf("Name of the interleaved diskimage?");
    #endif
    scanf("%50s", interleaved);
  } else strcpy(interleaved, argv[3+options]);



  fp0=fopen(side0,"rb");
  if (fp0==NULL) {
    #ifdef NL
    printf("Bestand %s is niet te openen\n\n", side0);
    #else
    printf("File %s cannot be opened\n\n", side0);
    #endif
    exit(1);
  }

  if (strcmp(side0,side1)) {
    /*alleen als twee verschillende bestanden */
    fp1=fopen(side1,"rb");
    if (fp1==NULL) {
      #ifdef NL
      printf("Bestand %s is niet te openen\n\n", side1);
      #else
      printf("File %s cannot be opened\n\n", side1);
      #endif
      exit(1);
    }
  } else fp1=fp0;


  fp_inter=fopen(interleaved, "wb");

  printf("  %s + %s > %s\n\n", side0, side1, interleaved);


  sec_per_track=10;
  if (dd) sec_per_track=18;


  fseek(fp0, 0L, SEEK_SET);
  fseek(fp1, 0L, SEEK_SET);
  fseek(fp_inter,0L, SEEK_SET);
  for (track=0; track<80;track++) {
    fseek(fp0,0L+track*256L*sec_per_track, SEEK_SET);
    for (i=0; i<256*sec_per_track; i++) {
      if (feof(fp0) && feof(fp1)) exit(0);
      if (feof(fp0)) byte=0; else fread(&byte,1,1,fp0);
      fwrite(&byte,1,1,fp_inter);
    }
    fseek(fp1,0L+track*256L*sec_per_track, SEEK_SET);
    for (i=0; i<256*sec_per_track; i++) {
      if (feof(fp1) && feof(fp0)) exit(0);
      if (feof(fp1)) byte=0; else fread(&byte,1,1,fp1);
      fwrite(&byte,1,1,fp_inter);
    }
  }
}
/*einde samenvoegen*/















/* SPLITS OM-EN-OM DISKBEELD: */

void splitds(int argc, char *argv[], int options) {
  char  side0[50],  side1[50], interleaved[50]; 
  char option2[5];
  unsigned char byte;
  FILE *fp0, *fp1, *fp_inter;
  int sec_per_track, track;

  int dd=0;

  if ((argc-options)==1) {
    #ifdef NL
    printf("Single density (sd) of double density (dd)?");
    #else
    printf("Single density (sd) or double density (dd)?");
    #endif
    scanf("%2s", option2);
  } else {strncpy(option2, argv[1+options],2); options++;}

  if (!strcmp(option2, "dd")) dd=1;


  if ((argc-options)==1) {
    #ifdef NL
    printf("Naam van de om-en-om diskdump?");
    #else
    printf("Name of the interleaved diskdump?");
    #endif
    scanf("%50s", interleaved);
  } else strcpy(interleaved, argv[1+options]);

  strcpy(side0, interleaved);
  side0[strcspn(side0,".")]=0;
  strcpy(side1, side0);
  strcat(side0,".0");
  strcat(side1,".1");

  printf(" %s > %s + %s\n\n",interleaved, side0, side1);

  fp_inter=fopen(interleaved, "rb");
  if (fp_inter==NULL) {
    #ifdef NL
    printf("Bestand %s is niet te openen\n\n", interleaved);
    #else
    printf("File %s cannot be opened\n\n", interleaved);
    #endif
    exit(1);
  }


  fp0=fopen(side0,"wb");
  fp1=fopen(side1,"wb");


  sec_per_track=10;
  if (dd) sec_per_track=18;

  fseek(fp_inter,0L, SEEK_SET);
  for (track=0; track<80;track++) {
    int i;
    for (i=0; i<256*sec_per_track; i++) {
      if (!fread(&byte,1,1,fp_inter)) exit(0);
      fwrite(&byte,1,1,fp0);
    }
    for (i=0; i<256*sec_per_track; i++) {
      if (!fread(&byte,1,1,fp_inter)) exit(0);
      fwrite(&byte,1,1,fp1);
    }
  }
} /*einde splitsen */

