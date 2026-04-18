// @import "../lib/gametrak.ck"


// GameTrak gt(0);


// --------------------- GAINS --------------------- //
[
    @(0.3, 0.3),
    @(0.5, 0.5),
    @(0.3, 0.3),
] @=> vec2 levels[];

Gain gainsLeft[0];
Gain gainsRight[0];
for (int i; i < levels.size(); i++) {
    gainsLeft << new Gain(levels[i].x);
    gainsRight << new Gain(levels[i].y);
}

// Connect gains to DAC (this is bad, be better)
for (int i; i < gainsLeft.size(); i++) {
    gainsLeft[i] => dac.chan(0);
    // gainsLeft[i] => dac.chan(2);
    // gainsLeft[i] => dac.chan(4);

    gainsRight[i] => dac.chan(1);
    // gainsRight[i] => dac.chan(3);
    // gainsRight[i] => dac.chan(5);
}

// -------------------- SOUND 1 -------------------- //
CNoise noise("white");
noise => LPF filterL(100.) => NRev revL => gainsLeft[0];
noise => LPF filterR(100.) => NRev revR => gainsRight[0];



SinOsc lfo(0.1) => blackhole;

fun void sound1() {
    while (true) {
        Std.scalef(lfo.last(), -1., 1., 30., 300) => filterL.freq;
        Std.scalef(lfo.last(), -1., 1., 30., 600) => filterR.freq;

        1::ms => now;
    }
} // spork ~ sound1();


// -------------------- SOUND 2 -------------------- //
BlowBotl bottle;
bottle => Chorus sound2ChorusL => NRev sound2revL => gainsLeft[1];
bottle => NRev sound2revR => gainsRight[1];

fun void sound2() {
    0.468725 => bottle.noiseGain;
    8.724864 => bottle.vibratoFreq;
    0.595734 => bottle.vibratoGain;
    0.702008 => bottle.volume;

    Std.mtof(60) => bottle.freq;

    while (true) {

        .8 => bottle.noteOn;

        // advance time
        1::second => now;
    }
} spork ~ sound2();

// -------------------- SOUND 3 -------------------- //
BlowHole hole => ADSR beep => gainsLeft[2];
beep => gainsRight[2];

beep.set(35::ms, 50::ms, 0.7, 100::ms);

0.742307 => hole.reed;
0.862736 => hole.noiseGain;
0.642372 => hole.tonehole;
0.051535 => hole.vent;
0.250131 => hole.pressure;
80 => hole.freq;
0.8 => hole.noteOn;


750 => int beepRate;
fun void sound3(dur initDelay) {
    initDelay => now;
    while (true) {
        beep.keyOn(1);
        100::ms => now;
        beep.keyOff(1);
        beepRate::ms => now;
    }
} spork ~ sound3(750::ms);


eon => now;


// // Gametrack effects
// while (true) {
//     Std.scalef(gt.axis[0], -1., 1., 30, 1000)$int => beepRate;
//     Std.scalef(gt.axis[3], -1, 1., 400, 30) => filterL.freq;
//     Std.scalef(gt.axis[3], -1, 1., 700, 30) => filterR.freq;
//     10::ms => now;
// }
