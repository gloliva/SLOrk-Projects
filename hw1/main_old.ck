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
Sequence seqLeft([48, 55, 60]);
Sequence seqRight([60, 63, 65, 67, 72]);


fun int getNoteIdx(float gtVal, int listSize) {
    listSize$float - 0.01 => float endVal;
    return Math.floor(Std.scalef(gtVal, -1., 1., 0., endVal))$int;
}


// Do music stuff
fun void makeMusic(int startIdx, Sequence seq) {
    PulseOsc osc[NUM_CHANNELS] => ADSR env[NUM_CHANNELS] => NRev rev[NUM_CHANNELS];

    for (int i; i < 6; i++) {
        0.1 => osc[i].gain;
        0.2 => rev[i].mix;
        env[i] => dac.chan(i);
        env[i].set(25::ms, 1000::ms, 0.7, 2500::ms);
    }


    0 => int envOn;
    0 => int currChanIdx;

    while (true) {
        if (gt.axis[startIdx + 2] > 0.07) {
            // Pulse width
            Std.scalef(gt.axis[startIdx + 1], -1., 1., 0.1, 0.9) => float width;
            Std.scalef(gt.axis[startIdx + 1], -1., 1., 0.1, 0.5) => float mix;
            for (int i; i < NUM_CHANNELS; i++) {
                width => osc[i].width;
                mix => rev[i].mix;
            }

            if (!envOn) {
                // Chan Idx
                Math.floor(Std.scalef(gt.axis[startIdx], -1., 1., 0., 5.99))$int => int chanIdx;
                <<< "Chan idx:", chanIdx >>>;
                chanIdx => currChanIdx;

                // Note
                getNoteIdx(gt.axis[startIdx], seq.size()) => int noteIdx;
                seq.notes()[noteIdx] => int note;
                Math.mtof(note) => osc[chanIdx].freq;

                // Env
                env[chanIdx].keyOn(1);
                1 => envOn;
            }
        } else if (gt.axis[startIdx + 2] < 0.068) {
            if (envOn) {
                env[currChanIdx].keyOff(1);
                0 => envOn;
            }
        }

        10::ms => now;
    }
}

spork ~ makeMusic(0, seqLeft);
spork ~ makeMusic(3, seqRight);


// Play the piece of music
20::second => now;
<<< "Changing notes" >>>;
seqLeft.notes([45, 52, 57]);
seqRight.notes([57, 60, 62, 64, 69]);
20::second => now;

20::second => now;
<<< "Changing notes" >>>;
seqLeft.notes([48, 55, 60]);
seqRight.notes([60, 61, 63, 65, 67, 68, 71, 72]);

eon => now;
