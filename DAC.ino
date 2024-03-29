//DAC program by Owen Christopher Chu (26921308)
//This program is used for the Arduino Due for use as a DAC interface.
//The ports listed under the 8 element array "digit[]" are the pin numbers used for data input from the FPGA.
//An extra pin is used to receive an activation signal from the FPGA, listed under "flag".
//When the flag returns a 1, the Arduino will read the "digit" pins and save the information in the 2D array "data".
//Once all 127 bits have been read, the board will modulate the data and output it through the DAC1 analog output pin.
//The incoming data will also be printed to the console for users to check.
//If there is only 1 FPGA available to test the receiving half of the system, the "sample_data[][]" 2D array with pre-filled data will be used instead of reading data from the FPGA.
//This can be changed by changing the value of the "mode" variable. This variable should only be set as either 0 or 1.
//If only the receiving half of the system is being tested, a different port will be used to receive a signal from the FPGA, telling the board to being transmitting the pre-filled data.
//The pin number used for this activation pin is listed under the variable "btn".

byte pack       = 0b00;

int flag        = 31;
int dly         = 1198;
int digit[8]    = {53, 51, 49, 47, 45, 43, 41, 39};
int pattern[8];
int data[16][8];
int mode = 1;

int sample_data[16][8] =  {                                                //The full 127-bit sequence the PRBS will output. Used to check for errors when only 1 FPGA is available.
                          {0, 0, 0, 0, 0, 0, 1, 0},
                          {0, 0, 0, 0, 1, 1, 0, 0},
                          {0, 0, 1, 0, 1, 0, 0 ,0},
                          {1, 1, 1, 1, 0, 0, 1, 0},
                          {0, 0, 1, 0, 1, 1, 0, 0},
                          {1, 1, 1, 0, 1, 0, 1, 0},
                          {0, 1, 1, 1, 1, 1, 0, 1},
                          {0, 0, 0, 0, 1, 1, 1, 0},
                          {0, 0, 1, 0, 0, 1, 0, 0},
                          {1, 1, 0, 1, 1, 0, 1, 0},
                          {1, 1, 0, 1, 1, 1, 1, 0},
                          {1, 1, 0, 0, 0, 1, 1, 0},
                          {1, 0, 0, 1, 0, 1, 1, 1},
                          {0, 1, 1, 1, 0, 0, 1, 1},
                          {0, 0, 1, 0, 1, 0, 1, 0},
                          {1, 1, 1, 1, 1, 1, 1, 0}};
                  
int flg_dat;
int old_flg;
int cntr;
int flg_read;
int btn = 29;
int button;
int old_button;

// the setup routine runs once when you press reset:
void setup() {                                                            //Setting the state of the input pins. The DAC pin doesn't need to be set as it can only be used for output.
  Serial.begin(9600);                                                     //Baud rate set for printing information to the console.
  pinMode(flag    , INPUT);
  pinMode(digit[0], INPUT);
  pinMode(digit[1], INPUT);
  pinMode(digit[2], INPUT);
  pinMode(digit[3], INPUT);
  pinMode(digit[4], INPUT);
  pinMode(digit[5], INPUT);
  pinMode(digit[6], INPUT);
  pinMode(digit[7], INPUT);
  pinMode(btn, INPUT);
}

// the loop routine runs over and over again forever:
void loop() {
  flg_dat = digitalRead(flag);
  button  = digitalRead(btn);
  if(((button && !old_button) && mode == 1) || (flg_dat && !old_flg))     //Triggers the modulation and output loop on the positive edge of either "flag" or "button", depending on the mode.
  {
    if(mode == 0)                                                         //Triggers data to be read when mode is set to 0.
    {
      for(int i = 0; i < 8; i++)
      {
        data[cntr][i] = digitalRead(digit[i]);
      }
      cntr++;
    }

    if(cntr >= 16 || mode == 1);
    {
      analogWrite(DAC1, 255);                                             //Simple header of the maximum value to trigger the ADC to start storing the modulated data.
      delayMicroseconds(dly);
      analogWrite(DAC1, 0);
      delayMicroseconds(dly);
      for(int j = 0; j < 16; j++)
      {
        for(int i = 0; i < 8; i = i + 2)                                  //Combining 2 bits into a single binary variable for use in the modulation process.
        {
          if(mode == 0)
          {
            bitWrite(pack, 0, data[j][i]);
            bitWrite(pack, 1, data[j][i+1]);

            Serial.print(data[j][i]);                                     //Outputs the data to the console for error checking.
            Serial.print(data[j][i+1]);
          }
          else
          {
            bitWrite(pack, 0, sample_data[j][i]);
            bitWrite(pack, 1, sample_data[j][i+1]);

            Serial.print(sample_data[j][i]);                              //Outputs the sample data to the console for error checking.
            Serial.print(sample_data[j][i+1]);
          }
          
          

          switch(pack)                                                    //Switch case to determine what voltage level should be sent based on the binary variable.
          {
            case 0b00:
              analogWrite(DAC1, 0);
              break;
            case 0b01:
              analogWrite(DAC1, 85);
              break;
            case 0b11:
              analogWrite(DAC1, 170);
              break;
            case 0b10:
              analogWrite(DAC1, 255);
              break;
            default:
              analogWrite(DAC1, 0);
              break;
          }
          delayMicroseconds(dly);                                         //Delay set to allow for the ADC to read the modulated data and prevent desync between the two boards.
        }
      }
      analogWrite(DAC1, 0);                                               //Reset the analog output pin
      Serial.print("\n");
      cntr = 0;
    }
  }
  old_flg = flg_dat;                                                      //Saving the current state of "flag" and "button" to provide edge detection.
  old_button = button;
}
