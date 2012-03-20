#include <plib.h>
#define SIN             70  //RA0 - Serial Connection to TLC5940
#define BLANK           37  //RE0 - Turn off display, GS Counter Reset
#define XLAT            36  //RE1 - Data Latch Signal (Update Levels)
#define GSCLK            3  //RD0 - Grayscale Reference Clock
#define SCLK            34  //RE3 - Serial Data Shift Clock
#define INH0            33  //RE4 
#define INH1            32  //RE5
#define INH2            31  //RE6
#define A               30  //RE7
#define B                2  //RE8
#define C                7  //RE9


#define PWM_TIME_WAIT   46 //****Change to match 3 MHz, not 500 kHz


volatile int cyclecount = 0;
volatile int waste = 0;
volatile int nextRow = 1;
volatile int currentRow = 0;
int testBrightness = 0;
void setup()
{
  //Change all pins to outputs
  pinMode(SIN,   OUTPUT);
  digitalWrite(SIN, LOW);
  pinMode(GSCLK, OUTPUT);
  digitalWrite(GSCLK, LOW);
  pinMode(SCLK,  OUTPUT);
  digitalWrite(SCLK, LOW);
  pinMode(XLAT,  OUTPUT);
  digitalWrite(XLAT, LOW);
  pinMode(BLANK, OUTPUT);
  digitalWrite(BLANK, LOW);
  pinMode(INH0,  OUTPUT);
  digitalWrite(INH0, LOW);
  pinMode(INH1,  OUTPUT);
  digitalWrite(INH1, LOW);
  pinMode(INH2,  OUTPUT);
  digitalWrite(INH2, LOW);
  pinMode(A,     OUTPUT);
  digitalWrite(A, LOW);
  pinMode(B,     OUTPUT);
  digitalWrite(B, LOW);
  pinMode(C,     OUTPUT);
  digitalWrite(C, LOW);
  pinMode(13,    OUTPUT);
  digitalWrite(13, HIGH);
  
  setupTimer3();
  setupOutputCompare1();
  timer3On();
}

void busyWait(int duration)
{
  for(waste=0; waste < duration; waste++);
}

void toggleSCLK() //RE3
{
  LATEINV = 0x0008; //Turn SCLK high
  waste++;
  LATEINV = 0x0008; //Turn SCLK low
}

void toggleXLAT() //RE1
{
  LATEINV = 0x0002; //Turn XLAT high
  waste++;
  LATEINV = 0x0002; //Turn XLAT low
}

void BLANKLow() //RE0
{
  LATECLR = 0x0001; //Turn BLANK low
}

void BLANKHigh() //RE0
{
  LATESET = 0X0001; //Turn Blank high
}

void toggleBLANK() //Toggle RE0
{
  BLANKHigh();
  BLANKLow();
}

void writeDataWord(unsigned int dataWord)
{
  unsigned int bitMask = 0x0800;
  for(int i=0; i<12; i++)
  {
    if(bitMask & dataWord)
      LATASET = 0x0001;
    else
      LATACLR = 0x0001;
    
    bitMask = bitMask>>1;
    toggleSCLK();
  }
}
    

void setupTimer3()
{
  // set up timer 3 for fast period
  T3CONCLR = _T3CON_ON_MASK;
  TMR3 = 0;
  PR3 = PWM_TIME_WAIT;
  
  // Configure Interrupt
  ConfigIntTimer3((T3_INT_ON | T3_INT_PRIOR_3));
  
}

void setupOutputCompare1()
{
  // set up output compare 1 to track timer 3 on rd0 (pin 3)
  OC1CONCLR = _OC1CON_ON_MASK;
  OC1R = 0;
  OC1RS = PWM_TIME_WAIT;
  OC1CON = _OC1CON_ON_MASK|_OC1CON_OCTSEL_MASK|(3<<_OC1CON_OCM0_POSITION);
}

void timer3On()
{
  T3CON |= 0x8000; 
}

void timer3Off()
{
  while((PORTD & 0x1) == 0x1); //Ensures when the timer shuts off, the GSCLK line is low.
  T3CON &= 0x7FFF;
}

void switchINH(int whichINH)
{
  switch(whichINH)
  {
  case 0: 
    LATECLR = 0x0010; //RE4 - L
    LATESET = 0x0020; //RE5 - H
    LATESET = 0x0040; //RE6 - H
    break;
  case 1:
    LATESET = 0x0010; //RE4 - H
    LATECLR = 0x0020; //RE5 - L
    LATESET = 0x0040; //RE6 - H
    break;
  case 2: 
    LATESET = 0x0010; //RE4 - H
    LATESET = 0x0020; //RE5 - H
    LATECLR = 0x0040; //RE6 - L
    break;
  }
}

void selectRow(int row)
{
  switch(row) //RE7, 8, AND 9
  {
  case 0:
    LATECLR = 0x0080; //RE7 - L
    LATECLR = 0x0100; //RE8 - L
    LATECLR = 0x0200; //RE9 - L
    break;
  case 1:
    LATESET = 0x0080; //RE7 - H
    LATECLR = 0x0100; //RE8 - L
    LATECLR = 0x0200; //RE9 - L
    break;
  case 2:
    LATECLR = 0x0080; //RE7 - L
    LATESET = 0x0100; //RE8 - H
    LATECLR = 0x0200; //RE9 - L
    break;
  case 3:
    LATESET = 0x0080; //RE7 - H
    LATESET = 0x0100; //RE8 - H
    LATECLR = 0x0200; //RE9 - L
    break;
  case 4:
    LATECLR = 0x0080; //RE7 - L
    LATECLR = 0x0100; //RE8 - L
    LATESET = 0x0200; //RE9 - H
    break;
  case 5:
    LATESET = 0x0080; //RE7 - H
    LATECLR = 0x0100; //RE8 - L
    LATESET = 0x0200; //RE9 - H
    break;
  case 6:
    LATECLR = 0x0080; //RE7 - L
    LATESET = 0x0100; //RE8 - H
    LATESET = 0x0200; //RE9 - H
    break;
  case 7:
    LATESET = 0x0080; //RE7 - H
    LATESET = 0x0100; //RE8 - H
    LATESET = 0x0200; //RE9 - H
    break;
  }
}

void updateDemuxes(int whichRow)
{
  int row = whichRow & 0x07;
  
  switchINH((whichRow & 0x18)>>3); //Select the appropriate INH.

  selectRow(row); //Change A, B, & C to select the next row.
}

#ifdef __cplusplus
extern "C" {
#endif
void __ISR(_TIMER_3_VECTOR,IPL3AUTO) Timer3handler(void)
{
  mT3ClearIntFlag();  // Clear interrupt flag
  cyclecount++;
  if(cyclecount >= 4096)
  {
    cyclecount = 0;
    LATEINV = 0x0001; //Turn BLANK high
    // Increment Rows
    currentRow++;
    toggleXLAT();
    LATEINV = 0x0001; //Turn BLANK low
    // Request Next set of data
    nextRow = 1;
  }
}
#ifdef __cplusplus
}
#endif

void loop()
{
  if(nextRow)
  {
    if(currentRow >= 5)
      currentRow = 0;
    updateDemuxes(currentRow);
    for(int i = 0; i < 72; i++)
    {
      writeDataWord(testBrightness);
    }
    testBrightness++;
    if(testBrightness > 4095)
      testBrightness = 0;
    nextRow = 0;
  }
} 

