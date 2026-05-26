@import {"../lib/gametrak.ck", "../lib/keyboard.ck"}
@import {"../lib/logger.ck", "../lib/osc.ck", "../lib/utils.ck"}
@import {"sounds.ck", "visuals.ck"}


// Command-line arguments
int performerId;
int oscSender;
if (me.args()) {
    me.arg(0) => Std.atoi => performerId;
    me.arg(1) => Std.atoi => oscSender;
}

if (performerId < 1 || performerId > 5) {
    Log.error("Performer ID set to incorrect value: " + performerId);
    me.exit();
}


// Init GameTrak
GameTrak gt(0);
if (!gt.good()) me.exit();
Log.print("GameTrak connected");


// Init Visuals
Visuals visuals;


// Init OSC Receiver
if (!oscSender) {
    OscReceiver receiver(Globals.stateChange);
    spork ~ receiver.listen();
}


// Init sounds
Wind wind(performerId);
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
        Globals.stateChange.broadcast();
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
visuals.updateLeft(-0.2, 0., -15);
visuals.updateRight(0.2, 0., -15);
Log.debug("Waiting to start...");
Globals.stateChange => now;


State scene1;
1 => scene1.running;


fun void scene1Sounds(State sceneState, int performerId) {
    Log.debug("Start Scene 1");

    // Wait depending on performer id
    ((performerId - 1) * 10)::second => now;

    Utils.ramp([wind.L, wind.R], 5::second, 1.);
    Utils.ramp([wind.noiseEnvL, wind.noiseEnvR], 5::second, 1.);
    20::second => now;

    Log.debug("Ramping up SinOsc");
    spork ~ Utils.ramp([wind.sinEnvL, wind.sinEnvR], [20::second, 20::second], [0.1, 1.]);
    40::second => now;

    Log.debug("Ramp down noise");
    Utils.ramp([wind.noiseEnvL, wind.noiseEnvR], 30::second, 0.) => now;

    // Stop visuals
    0 => sceneState.running;
    Log.debug("Ramping up FM params, waiting in middle");
    Utils.ramp([wind.fmEnvL, wind.fmEnvR], 5::second, 1.) => now;
    ((5 - (performerId - 1)) * 10)::second => now;


    Log.debug("Wait movement + tether release");
    20::second => now;
    Log.debug("Done with Scene 1");

    // Scene 2 handles stopping this shred
    eon => now;
}


fun void scene1Movement(State sceneState, int performerId) {
    // Wait depending on performer id

    now => time start;

    "Scene 1 - Wait" => visuals.updateText;
    ((performerId - 1) * 10)::second => now;
    "Scene 1 - Raise Tethers" => visuals.updateText;

    spork ~ visuals.transformLeft(-0.2, 1.5, 0.5, 10::second);
    spork ~ visuals.transformRight(0.2, 1.5, 0.5, 10::second);
    10::second => now;

    "Scene 1 - Rotate Clockwise" => visuals.updateText;

    SinOsc x(0.2) => blackhole;
    SinOsc y(0.2) => blackhole;

    5::second => x.period => y.period;
    0.25 => y.phase;

    while (sceneState.running) {
        Std.scalef(x.last(), -1., 1., -1.5, 1.5) => float x;
        Std.scalef(y.last(), -1., 1., -1.5, 1.5) => float y;

        visuals.updateLeft(x - 0.2, y, 0.5);
        visuals.updateRight(x + 0.2 , y, 0.5);
        10::ms => now;
    }

    "Scene 1 - Move to Middle" => visuals.updateText;
    spork ~ visuals.transformLeft(-0.2, 0., 0.5, 5::second);
    spork ~ visuals.transformRight(0.2, 0., 0.5, 5::second);
    5::second => now;

    "Scene 1 - Hold in Middle" => visuals.updateText;
    ((5 - (performerId - 1)) * 10)::second => now;

    "Scene 1 - Move tethers" => visuals.updateText;

    [1.5, 0., 0., 0., -1.5] @=> float xs[];
    [0., 1.5, -1.5, 1.5, 0.] @=> float ys[];
    spork ~ visuals.transformLeft(xs[performerId - 1] - 0.2, ys[performerId - 1], 0.5, 5::second);
    spork ~ visuals.transformRight(xs[performerId - 1] + 0.2, ys[performerId - 1], 0.5, 5::second);
    5::second => now;

    "Scene 1 - Prepare to Release" => visuals.updateText;
    spork ~ visuals.countdown(5);
    5::second => now;

    "Scene 1 - Release tether!" => visuals.updateText;
    spork ~ visuals.transformLeft(-0.2, 0., -15., 1::second);
    spork ~ visuals.transformRight(0.2, 0., -15., 1::second);
    5::second => now;


    <<< "TOTAL TIME IN SECS:", (now - start) / 1::second >>>;

    // Scene 2 handles stopping this shred
    "Scene 1 - Wait" => visuals.updateText;
    eon => now;
}


// Scene 1
spork ~ scene1Sounds(scene1, performerId) @=> Shred scene1SoundsShred;
spork ~ scene1Movement(scene1, performerId) @=> Shred scene1MovementShred;

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
20::second => now;

spork ~ visuals.transformLeft(-1.7, 0., 0.5, 5::second);
spork ~ visuals.transformRight(-1.3, 0., 0.5, 5::second);
20::second => now;

spork ~ visuals.transformRight(1.7, 0., 0.5, 5::second);
20::second => now;

spork ~ visuals.transformRight(0.2, 1.5, 0.5, 5::second);
20::second => now;

spork ~ visuals.transformLeft(-0.2, 1.5, 0.5, 5::second);
20::second => now;

spork ~ visuals.transformLeft(-0.2, -1.5, 0.5, 5::second);
spork ~ visuals.transformRight(0.2, -1.5, 0.5, 5::second);
20::second => now;


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
