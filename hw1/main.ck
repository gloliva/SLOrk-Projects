@import "instrument.ck"
@import "gametrack.ck"
@import "sequence.ck"


// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;


// Set number of channels, 6 for the hemis
6 => int NUM_CHANNELS;


// Handle gametrack
GameTrak gt(device);
spork ~ gt.run();


// Create sequences
Sequence seqLeft([48, 55, 58]);
Sequence seqRight([60, 63, 65, 67, 72]);


// Create PulseWidthMod update object
PWMUpdates pwm(0.2, 2.);


fun int getNoteIdx(float gtVal, int listSize) {
    listSize$float - 0.01 => float endVal;
    return Math.floor(Std.scalef(gtVal, -1., 1., 0., endVal))$int;
}


// Do music stuff
fun void makeMusic(int startIdx, Sequence seq, PWMUpdates pwm) {
    PulseWidthOsc osc[NUM_CHANNELS];
    ADSR env[NUM_CHANNELS] => NRev rev[NUM_CHANNELS];

    for (int i; i < 6; i++) {
        // Connect osc instrument to the DAC chain
        osc[i].out => env[i];

        // set up ugens
        0.1 => osc[i].gain;
        0.4 => rev[i].mix;

        env[i] => dac.chan(i);
        env[i].set(25::ms, 1000::ms, 0.7, 2500::ms);
    }

    0 => int envOn;
    0 => int currChanIdx;

    while (true) {
        if (gt.axis[startIdx + GameTrak.Z] > 0.09) {
            // Pulse width
            Std.scalef(gt.axis[startIdx + GameTrak.Y], -1., 1., pwm.low, pwm.high) => float pwmFreq;
            for (int i; i < NUM_CHANNELS; i++) {
                pwmFreq => osc[i].pwmFreq;
            }

            if (!envOn) {
                // Chan Idx
                Math.floor(Std.scalef(gt.axis[startIdx + GameTrak.X], -1., 1., 0., 5.99))$int => int chanIdx;
                chanIdx => currChanIdx;

                // Note
                getNoteIdx(gt.axis[startIdx + GameTrak.X], seq.size()) => int noteIdx;
                seq.notes()[noteIdx] => int note;
                Math.mtof(note) => osc[chanIdx].freq;

                // Env
                env[chanIdx].keyOn(1);
                1 => envOn;
            }
        } else if (gt.axis[startIdx + GameTrak.Z] < 0.09) {
            if (envOn) {
                env[currChanIdx].keyOff(1);
                0 => envOn;
            }
        }

        1::ms => now;
    }
}

// Start the piece
// Use the gametrak button to transition between parts
spork ~ makeMusic(0, seqLeft, pwm);
spork ~ makeMusic(3, seqRight, pwm);
<<< "Section 1" >>>;


gt.buttonPress => now;
<<< "Section 2: Changing notes" >>>;
seqLeft.notes([45, 52, 55]);
seqRight.notes([57, 60, 62, 64, 69]);


gt.buttonPress => now;
<<< "Section 3: Changing notes + PWM" >>>;
pwm.set(0.2, 5.);
seqLeft.notes([48, 55, 58]);
seqRight.notes([60, 63, 65, 67, 72]);


gt.buttonPress => now;
<<< "Section 4: Changing notes + PWM" >>>;
pwm.set(0.2, 10.);
seqLeft.notes([45, 52, 55]);
seqRight.notes([57, 60, 62, 64, 69]);


gt.buttonPress => now;
<<< "Section 5: Chaos" >>>;
pwm.set(0.2, 120.);


gt.buttonPress => now;
<<< "Goodbye!" >>>;
