@import "../lib/gametrak.ck"
@import "../lib/keyboard.ck"
@import "../lib/logger.ck"
@import "../lib/utils.ck"
@import "Range"


// Keyboard
Keyboard kb(1);


// UGens
Envelope mixer[dac.channels()];
Range range[GameTrak.NUM_AXES + GameTrak.NUM_BUTTONS];

for (int chan; chan < dac.channels(); chan++) {
    mixer[chan] => dac.chan(chan);
}


// GameTrak handling
GameTrak gt(0, 0.04);
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