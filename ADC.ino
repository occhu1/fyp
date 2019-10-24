//ADC program by Owen Christopher Chu (26921308)
//This program is used for the Arduino Uno for use as an ADC interface.
//The ports listed under the 8 element array "outpin[]" are the pin numbers used for outputting demodulated data to the receiving FPGA.
//The analog receiving pin "a_in" will receive modulated data from the DAC.
//After the header is received from the DAC, data will be saved to the 65 element array "data". Even though there are meant to be 64 bits of data being sent from the DAC, an extra element is there in case the ADC reads an extra bit of data.
//After all 65 bits of data has been read, the board will begin demodulating the information using thresholds.
//The demodulated information will be stored in the 2D array "demod[][]".
//The ADC will then write the data to the data bus in groups of 8 bits and a flag signal will be sent to the FPGA to being reading the bus.

int flag        = 12;
int a_in        = A1;
int outpin[8]   = {2, 3, 4, 5, 6, 7, 8, 9};
int data[65];
int demod[16][8];
int signal_rec;
int an_receive;
int dly = 0;

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);                                                               //Setting the state of the input pins.
  pinMode(flag, OUTPUT);                                                            //Baud rate set for printing information to the console.
  pinMode(outpin[0], OUTPUT);
  pinMode(outpin[1], OUTPUT);
  pinMode(outpin[2], OUTPUT);
  pinMode(outpin[3], OUTPUT);
  pinMode(outpin[4], OUTPUT);
  pinMode(outpin[5], OUTPUT);
  pinMode(outpin[6], OUTPUT);
  pinMode(outpin[7], OUTPUT);
  pinMode(a_in, INPUT);
}

void loop() {
  // put your main code here, to run repeatedly:

  an_receive = analogRead(a_in);
  if(an_receive >= 500)                                                           //Once the header has been received, the following 65 bits will be stored.
  {
    delayMicroseconds(2300);                                                      //Delay between the first header bit and the start of the modulated data
    for(int i = 0; i < 65; i++)
    {
      data[i] = analogRead(a_in);                                                 //Reading the incoming data and saving it to the array.
      delayMicroseconds(1100);                                                    //Delay to allow for reading the data and prevent desync between the two boards.
    }
    
    if(data[3] < 200)                                                             //Error checker to determine if an extra bit of data has been read between the header and the first bit of data.
    {
      for(int i = 1; i < 65; i++)
      {
        data[i-1] = data[i];                                                      //If an extra bit of data has been read, all bits of data will be shifted down 
      }
    }
    
    for(int i = 0; i < 65; i++)
    {
      Serial.print(data[i]);                                                      //Printing the modulated data values to the console.
      Serial.print("\n");
    }
    
    for(int j = 0; j < 16; j++)
    {
      for(int i = 0; i < 8; i = i+2)
      {
        int k = i/2;
        if(data[(4*j) + k] < 150)                                                 //Demodulation via thresholding.
        {
          demod[j][i] = 0;
          demod[j][i+1] = 0;
        }
        else if(data[(4*j) + k] < 300)
        {
          demod[j][i] = 1;
          demod[j][i+1] = 0;
        }
        else if(data[(4*j) + k] < 500)
        {
          demod[j][i] = 1;
          demod[j][i+1] = 1;
        }
        else
        {
          demod[j][i] = 0;
          demod[j][i+1] = 1;
        }
        Serial.print(demod[j][i]);
        Serial.print(demod[j][i+1]);
      }
      Serial.print("\n");
    }
    Serial.print("\n");
    for(int j = 0; j < 16; j++)                                                   //Loop to write the data to the data bus in groups of 8. A delay has been set between writing to each pin to prevent cross talk.
    {
      digitalWrite(outpin[0], demod[j][0]);
      delayMicroseconds(dly);
      digitalWrite(outpin[1], demod[j][1]);
      delayMicroseconds(dly);
      digitalWrite(outpin[2], demod[j][2]);
      delayMicroseconds(dly);
      digitalWrite(outpin[3], demod[j][3]);
      delayMicroseconds(dly);
      digitalWrite(outpin[4], demod[j][4]);
      delayMicroseconds(dly);
      digitalWrite(outpin[5], demod[j][5]);
      delayMicroseconds(dly);
      digitalWrite(outpin[6], demod[j][6]);
      delayMicroseconds(dly);
      digitalWrite(outpin[7], demod[j][7]);

      delay(25);
      digitalWrite(flag, 1);
      delay(1);
      digitalWrite(flag, 0);
      delay(1);
    }
    Serial.print("\n");
  }
}
