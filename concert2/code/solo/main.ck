@import {"../lib/gametrak.ck", "../lib/keyboard.ck", "../lib/logger.ck", "../lib/utils.ck"}
@import "Range"


int runOnHemi;
if (me.args()) {
    me.arg(0) => Std.atoi => runOnHemi;
}
Log.debug("Running with hemi? " + runOnHemi);
Log.debug("Number of dac channels " + dac.channels());

Dyno dyno[Globals.NUM_ES8_INPUTS];
Gain eurorackAudio[Globals.NUM_ES8_INPUTS];


for (int i; i < Globals.NUM_ES8_INPUTS; i++) {
    dyno[i] => eurorackAudio[i];
    dyno[i].limit();
    5. => dyno[i].gain;
}


// The DAC should always be an aggregate device: ES8 + Audio Interface
// If running without the Hemi, it is assumed that the Audio Interface is 2 channels:
//    The first 16 channels are the ES8
//    The next 2 channels are the stereo audio interface
// If running WITH the Hemi:
//    The first 16 channels are the ES8 output
//    The next 6 channels are the Hemi speakers
//    The next 2 channels are the Subwoofer speakers (if using)
if (runOnHemi) {
    if (dac.channels() < Globals.NUM_ES8_OUTPUTS + Globals.NUM_HEMI_CHANS) {
        Log.error("Number of DAC channels not enough for both ES8 + Hemi.");
        me.exit();
    } else if (adc.channels() < Globals.NUM_ES8_INPUTS) {
        Log.error("Number of ADC channels not enough for ES8 audio inputs.");
        me.exit();
    }

    // Connect Audio from Eurorack --> Hemi
    for (int i; i < Globals.NUM_ES8_INPUTS; i++) {
        0.8 => eurorackAudio[i].gain;
        adc.chan(i) => eurorackAudio[i];
    }

    Log.print("Connecting Eurorack output to Hemi");
    Utils.stereoToDac(eurorackAudio[0], eurorackAudio[1], Globals.NUM_ES8_OUTPUTS);
} else {
    adc.chan(0) => dyno[0];
    adc.chan(1) => dyno[1];
    eurorackAudio[0] => dac.chan(Globals.NUM_ES8_OUTPUTS);
    eurorackAudio[1] => dac.chan(Globals.NUM_ES8_OUTPUTS + 1);

    0.5 => eurorackAudio[0].gain => eurorackAudio[1].gain;
}


// Init Keyboard
Utils.getKeyboardDeviceId() => int id;
Keyboard kb(id);


// UGens
Envelope mixer[Globals.NUM_ES8_OUTPUTS];
Range range[GameTrak.NUM_AXES + GameTrak.NUM_BUTTONS];

for (int chan; chan < Globals.NUM_ES8_OUTPUTS; chan++) {
    mixer[chan] => dac.chan(chan);
}


// Init GameTrak
GameTrak gt(0);
if (!gt.good()) me.exit();
Log.print("GameTrak connected");


for (int i; i < gt.outs.size(); i++) {
    gt.outs[i] => range[i];
}


// Set initial ranges
(-1., 1., -1., 1.) => range[0].range;
(-1., 1., -1., 1.) => range[1].range;
(0., 1., 0., 1.)   => range[2].range;
(-1., 1., -1., 1.) => range[3].range;
(-1., 1., -1., 1.) => range[4].range;
(0., 1., 0., 1.)   => range[5].range;
(0., 1., 0., 1.)   => range[6].range;


// Scene 1
Utils.ramp(mixer, [0, 1, 2, 3, 4, 5], 5::second, 1.);

(-1., 1., 0., 1.) => range[3].range;
Utils.map(range, mixer, [@(2, 0), @(0, 1), @(6, 2), @(5, 3), @(3, 4), @(2, 5)]);
kb.event => now;
kb.event => now;


// Scene 2
Utils.ramp(mixer, [0, 1, 2, 3, 4, 5], 5::second, 0.);
Utils.ramp(mixer, [2, 8, 9, 10, 11], 5::second, 1.);

(-1., 1., -1., 1.) => range[3].range;
Utils.map(range, mixer, [@(0, 8), @(1, 9), @(3, 10), @(4, 11), @(6, 2)]);
kb.event => now;
kb.event => now;

Utils.ramp(mixer, [2, 8, 9, 10, 11], 5::second, 0.) => now;