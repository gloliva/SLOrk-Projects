SndBuf2 buf1("/Users/gloliva/Downloads/among-us/assets/ElectricHum_BW.44833.wav");
SndBuf2 buf2("/Users/gloliva/Downloads/among-us/assets/SciFiWorkshop_S08SF.1719.wav");

1 => buf1.loop;
1 => buf2.loop;

buf1 => Gain gains[2];
buf2 => gains;

0.3 => gains[0].gain;
0.3 => gains[1].gain;

gains[0] => NRev revL => dac.chan(0);
gains[1] => NRev revR => dac.chan(1);


buf1.play(1.);
buf2.play(1.);

eon => now;