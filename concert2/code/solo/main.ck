@import {"../lib/gametrak.ck", "../lib/keyboard.ck"}
@import {"../lib/logger.ck", "../lib/osc.ck", "../lib/utils.ck"}
@import "Range"


// Command-line arguments
int runOnHemi;
if (me.args()) {
    me.arg(0) => Std.atoi => runOnHemi;
}
Log.debug("Running with hemi? " + runOnHemi);
Log.debug("Number of dac channels " + dac.channels());


// Handle Audio from Eurorack --> Hemi / Audio Interface
Dyno dyno[Globals.NUM_ES8_AUDIO_INPUTS];
Gain eurorackInputs[Globals.NUM_ES8_INPUTS];
for (int i; i < Globals.NUM_ES8_AUDIO_INPUTS; i++) {
    dyno[i] => eurorackInputs[i];
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
        0.8 => eurorackInputs[i].gain;
        adc.chan(i) => eurorackInputs[i];
    }

    Log.print("Connecting Eurorack output to Hemi");
    Utils.stereoToDac(eurorackInputs[0], eurorackInputs[1], Globals.NUM_ES8_OUTPUTS);
} else {
    adc.chan(0) => dyno[0];
    adc.chan(1) => dyno[1];
    eurorackInputs[0] => dac.chan(Globals.NUM_ES8_OUTPUTS);
    eurorackInputs[1] => dac.chan(Globals.NUM_ES8_OUTPUTS + 1);

    // Handle non-audio inputs
    adc.chan(2) => eurorackInputs[2];
    adc.chan(3) => eurorackInputs[3];

    0.5 => eurorackInputs[0].gain => eurorackInputs[1].gain;
}


// State Change Management: Local + OSC
fun void stateHandler() {
    // Init keyboard
    Utils.getKeyboardDeviceId() => int id;
    Keyboard kb(id);

    // Init OSC
    OscSender sender;
    1 => int state;

    while (true) {
        kb.event => now;

        if (kb.event.state == KeyboardEvent.DOWN && kb.event.data == Keyboard.SPACE_BAR) {
            Globals.stateChange.broadcast();
            spork ~ sender.send("/state", state);
            state++;
        }
    }
} spork ~ stateHandler();


// Envelope handling for Eurorack inputs
eurorackInputs[3] => Envelope scene1Env => dac.chan(15);
Step volume(0.) => Envelope scene2Env => dac.chan(15);


// GameTrak --> ES8 UGens
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


fun void gtHandler() {
    while (true) {
        gt.outs[GameTrak.LEFT_Z].next() => volume.next;
        10::ms => now;
    }
} spork ~ gtHandler();


// Set initial ranges
(-1., 1., -1., 1.) => range[0].range;
(-1., 1., -1., 1.) => range[1].range;
(0., 1., 0., 1.)   => range[2].range;
(-1., 1., -1., 1.) => range[3].range;
(-1., 1., -1., 1.) => range[4].range;
(0., 1., 0., 1.)   => range[5].range;
(0., 1., 0., 1.)   => range[6].range;


// Initial state
Log.print("Waiting to start...");
Globals.stateChange => now;


// Scene 1
Log.print("Scene 1");
Utils.ramp(mixer, [0, 1, 2, 3, 4, 5], 5::second, 1.);
scene1Env.ramp(5::second, 1.);

(-1., 1., 0., 1.) => range[3].range;
Utils.map(range, mixer, [@(2, 0), @(0, 1), @(6, 2), @(5, 3), @(3, 4), @(2, 5)]);
Globals.stateChange => now;


// Scene 2
Log.print("Scene 2");
Utils.ramp(mixer, [0, 1, 2, 3, 4, 5], 15::second, 0.);
Utils.ramp(mixer, [8, 9, 10, 11], 15::second, 1.);

scene1Env.ramp(15::second, 0.);
scene2Env.ramp(15::second, 1.);

(-1., 1., -1., 1.) => range[3].range;
Utils.map(range, mixer, [@(0, 8), @(1, 9), @(3, 10), @(4, 11), @(6, 2)]);
Globals.stateChange => now;


// Scene 3
// Nothing changes
Log.print("Scene 3");
Globals.stateChange => now;


// Scene 4
Log.print("Scene 4");
(-1., 1., 0., 1.) => range[3].range;
Utils.ramp(mixer, [0, 1, 2, 3, 4, 5], 15::second, 1.);

scene1Env.ramp(15::second, 1.);
scene2Env.ramp(15::second, 0.);

Globals.stateChange => now;


// End
Log.print("End of piece");
