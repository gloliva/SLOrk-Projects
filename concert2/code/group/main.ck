@import {"../lib/gametrak.ck", "../lib/keyboard.ck", "../lib/logger.ck", "../lib/utils.ck"}
@import "sounds.ck"


// Init GameTrak
GameTrak gt(0);
if (!gt.good()) me.exit();
Log.print("GameTrak connected");


// Init sounds
Wind wind;
Utils.stereoToDac(wind.L, wind.R);

Pulse pulse;
Utils.stereoToDac(pulse.L, pulse.R);


fun void localStateHandler() {
    Utils.getKeyboardDeviceId() => int id;
    Keyboard kb(id);

    while (true) {
        kb.event => now;

        if (kb.event.state == KeyboardEvent.DOWN && kb.event.data == Keyboard.SPACE_BAR) {
            Globals.stateChange.broadcast();
        }
    }
} spork ~ localStateHandler();


fun void gtHandler() {
    while (true) {
        // Wind
        (gt.outs[gt.LEFT_X].next(), gt.outs[gt.RIGHT_X].next()) => wind.freq;
        (gt.outs[gt.LEFT_Y].next(), gt.outs[gt.RIGHT_Y].next()) => wind.swell;
        (gt.outs[gt.LEFT_Z].next(), gt.outs[gt.RIGHT_Z].next()) => wind.gain;

        // pulse
        (gt.outs[gt.LEFT_X].next(), gt.outs[gt.RIGHT_X].next()) => pulse.freq;
        (gt.outs[gt.LEFT_Y].next(), gt.outs[gt.RIGHT_Y].next()) => pulse.width;
        (gt.outs[gt.LEFT_Z].next(), gt.outs[gt.RIGHT_Z].next()) => pulse.gain;

        10::ms => now;
    }
} spork ~ gtHandler();


Log.debug("Waiting to start...");
Globals.stateChange => now;


fun void scene1() {
    Log.debug("Start Scene 1");
    Utils.ramp([wind.L, wind.R], 5::second, 1.);
    Utils.ramp([wind.noiseEnvL, wind.noiseEnvR], 5::second, 1.);
    10::second => now;

    Log.debug("Ramping up SinOsc");
    spork ~ Utils.ramp([wind.sinEnvL, wind.sinEnvR], [20::second, 20::second], [0.1, 1.]);
    40::second => now;

    Log.debug("Ramp up bass, ramp down Sin");
    Utils.ramp([wind.bassEnv], 30::second, 1.);
    Utils.ramp([wind.sinEnvL, wind.sinEnvR], 50::second, 0.) => now;

    Log.debug("Ramp noise down");
    Utils.ramp([wind.noiseEnvL, wind.noiseEnvR], 20::second, 0.) => now;
    Log.debug("Done with Scene 1");
}


// Scene 1
spork ~ scene1();
Globals.stateChange => now;
Utils.ramp([wind.L, wind.R], 20::second, 0.) => now;


// Scene 2
Log.print("Scene 2");
// spork ~ Utils.ramp([pulse.L, pulse.R], [40::second, 10::second, 10::second], [0.1, 0.2, 0.5]);
Utils.ramp([pulse.L, pulse.R], 5::second, 1.);
eon => now;
