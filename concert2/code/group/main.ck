@import {"../lib/gametrak.ck", "../lib/keyboard.ck"}
@import {"../lib/logger.ck", "../lib/osc.ck", "../lib/utils.ck"}
@import {"sounds.ck", "visuals.ck"}


// Command-line arguments
int oscSender;
if (me.args()) {
    me.arg(0) => Std.atoi => oscSender;
}


// Init GameTrak
GameTrak gt(0);
if (!gt.good()) me.exit();
Log.print("GameTrak connected");


// Init Visuals
Visuals visuals;


// Init OSC Receiver
OscReceiver receiver(Globals.stateChange);
spork ~ receiver.listen();


// Init sounds
Wind wind;
Utils.stereoToDac(wind.L, wind.R);

Pulse pulse;
Utils.stereoToDac(pulse.L, pulse.R);


// State Change Management: Local + OSC
fun void emergencyStateHandler() {
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

            if (oscSender) {
                spork ~ sender.send("/state", state);
                state++;
            }
        }
    }
} spork ~ emergencyStateHandler();


fun void noSoloStateHandler() {
    // Function for testing group code without solo code
    if (!oscSender) return;

    // Init OSC
    OscSender sender;
    1 => int state;

    while (true) {
        gt.buttonPress => now;
        spork ~ sender.send("/state", state);
        state++;
    }
} spork ~ noSoloStateHandler();


public class State {
    int running;
}


// GameTrak to sound mapping
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


// Initial state
visuals.updateLeft(-0.2, 0., -5);
visuals.updateRight(0.2, 0., -5);
Log.debug("Waiting to start...");
Globals.stateChange => now;


State scene1;
1 => scene1.running;


fun void scene1Sounds(State sceneState) {
    Log.debug("Start Scene 1");
    Utils.ramp([wind.L, wind.R], 5::second, 1.);
    Utils.ramp([wind.noiseEnvL, wind.noiseEnvR], 5::second, 1.);
    20::second => now;

    Log.debug("Ramping up SinOsc");
    spork ~ Utils.ramp([wind.sinEnvL, wind.sinEnvR], [20::second, 20::second], [0.1, 1.]);
    40::second => now;

    Log.debug("Ramp up bass, ramp down Sin");
    Utils.ramp([wind.bassEnv], 30::second, 1.);
    Utils.ramp([wind.sinEnvL, wind.sinEnvR], 40::second, 0.) => now;

    // Stop visuals
    0 => scene1.running;
    spork ~ visuals.transformLeft(-0.2, 0., 0.5, 5::second);
    spork ~ visuals.transformRight(0.2, 0., 0.5, 5::second);

    Log.debug("Ramp noise down");
    Utils.ramp([wind.noiseEnvL, wind.noiseEnvR], 20::second, 0.) => now;
    Log.debug("Done with Scene 1");

    // Scene 2 handles stopping this shred
    eon => now;
}


fun void scene1Movement(State sceneState) {
    spork ~ visuals.transformLeft(-0.2, 1.5, 0.5, 10::second);
    spork ~ visuals.transformRight(0.2, 1.5, 0.5, 10::second);
    10::second => now;

    SinOsc x(0.2) => blackhole;
    SinOsc y(0.2) => blackhole;
    0.25 => y.phase;

    while (sceneState.running) {
        Std.scalef(x.last(), -1., 1., -1.5, 1.5) => float x;
        Std.scalef(y.last(), -1., 1., -1.5, 1.5) => float y;

        visuals.updateLeft(x - 0.2, y, 0.5);
        visuals.updateRight(x + 0.2 , y, 0.5);
        10::ms => now;
    }

    // Scene 2 handles stopping this shred
    eon => now;
}


// Scene 1
spork ~ scene1Sounds(scene1) @=> Shred scene1SoundsShred;
spork ~ scene1Movement(scene1) @=> Shred scene1MovementShred;

Log.print("Waiting for state change");
Globals.stateChange => now;


// Scene 2
Log.print("Scene 2");
scene1SoundsShred.exit();
scene1MovementShred.exit();
spork ~ visuals.transformLeft(-0.2, 0., -5., 5::second);
spork ~ visuals.transformRight(0.2, 0., -5., 5::second);
Utils.ramp([wind.L, wind.R], 20::second, 0.);

Log.print("Waiting for state change");
Globals.stateChange => now;


// Scene 3
Log.print("Scene 3");
// spork ~ Utils.ramp([pulse.L, pulse.R], [40::second, 10::second, 10::second], [0.1, 0.2, 0.5]);
Utils.ramp([pulse.L, pulse.R], 15::second, 1.);

spork ~ visuals.transformLeft(-0.2, -1.5, 0.5, 5::second);
spork ~ visuals.transformRight(0.2, -1.5, 0.5, 5::second);
15::second => now;

spork ~ visuals.transformLeft(-1.7, 0., 0.5, 5::second);
spork ~ visuals.transformRight(-1.3, 0., 0.5, 5::second);
15::second => now;

spork ~ visuals.transformRight(1.7, 0., 0.5, 5::second);
15::second => now;

spork ~ visuals.transformLeft(-0.2, 1.5, 0.5, 5::second);
spork ~ visuals.transformRight(0.2, 1.5, 0.5, 5::second);
15::second => now;


Log.print("Waiting for state change");
Globals.stateChange => now;

spork ~ visuals.transformLeft(0.0, 0., -5., 5::second);
spork ~ visuals.transformRight(0.0, 0., -5., 5::second);
5::second => now;


Log.print("Waiting for state change");
Globals.stateChange => now;


// Scene 4
Log.print("Scene 4");
Utils.ramp([pulse.L, pulse.R], 10::second, 0.);

Log.print("Waiting for state change");
Globals.stateChange => now;


// End
Log.print("End of piece");
