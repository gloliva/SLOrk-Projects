@import {"../lib/gametrak.ck", "../lib/keyboard.ck"}
@import {"../lib/logger.ck", "../lib/osc.ck", "../lib/utils.ck"}
@import "../visuals.ck"
@import "sounds.ck"


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
performerId => visuals.updateId;


// Init OSC Receiver
if (!oscSender) {
    OscReceiver receiver(Globals.stateChange);
    spork ~ receiver.listen();
}


// Init sounds
Wind wind(performerId);
Utils.stereoToDac(wind.L, wind.R);

Vibe vibe();
Utils.stereoToDac(vibe.L, vibe.R);


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
        Globals.stateChange.broadcast();
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
        (gt.outs[gt.LEFT_X].next(), gt.outs[gt.RIGHT_X].next()) => vibe.freq;
        (gt.outs[gt.LEFT_Y].next(), gt.outs[gt.RIGHT_Y].next()) => vibe.swell;
        (gt.outs[gt.LEFT_Z].next(), gt.outs[gt.RIGHT_Z].next()) => vibe.trigger;

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
    Log.debug("Scene 1");

    now => time start;

    // Wait depending on performer id
    ((performerId - 1) * 5)::second => now;

    Utils.ramp([wind.L, wind.R], 5::second, 1.);
    Utils.ramp([wind.noiseEnvL, wind.noiseEnvR], 5::second, 1.);
    15::second => now;

    Log.debug("Ramping up SinOsc");
    spork ~ Utils.ramp([wind.sinEnvL, wind.sinEnvR], [20::second, 20::second], [0.1, 1.]);
    40::second => now;

    Log.debug("Ramp down noise");
    Utils.ramp([wind.noiseEnvL, wind.noiseEnvR], (5 * (6 - performerId))::second, 0.);
    repeat(6 - performerId) {
        5::second => now;
    }

    // Stop visuals
    0 => sceneState.running;

    5::second => now;
    Log.debug("Wait movement + tether release");
    20::second => now;

    <<< "SOUND: TOTAL TIME IN SECS:", (now - start) / 1::second >>>;
    Log.debug("Done with Scene 1");
}


fun void scene1Movement(State sceneState, int performerId) {
    now => time start;

    // Wait depending on performer id
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

    if (performerId == 2 || performerId == 4) {
        "Scene 1 - Hold Position" => visuals.updateText;
    } else {
        "Scene 1 - Move to Middle" => visuals.updateText;
        spork ~ visuals.transformLeft(-0.2, 0., 0.5, 5::second);
        spork ~ visuals.transformRight(0.2, 0., 0.5, 5::second);
    }
    5::second => now;

    if (performerId != 2 && performerId != 4) {
        "Scene 1 - Move tethers" => visuals.updateText;
    }

    [1.5, 0., 0., 0., -1.5] @=> float xs[];
    [0., 1.5, -1.5, 1.5, 0.] @=> float ys[];
    spork ~ visuals.transformLeft(xs[performerId - 1] - 0.2, ys[performerId - 1], 0.5, 5::second);
    spork ~ visuals.transformRight(xs[performerId - 1] + 0.2, ys[performerId - 1], 0.5, 5::second);
    10::second => now;

    "Scene 1 - Prepare to Release" => visuals.updateText;
    spork ~ visuals.countdown(5);
    5::second => now;

    "Scene 1 - Release tethers!" => visuals.updateText;
    spork ~ visuals.transformLeft(-0.2, 0., -15., 1::second);
    spork ~ visuals.transformRight(0.2, 0., -15., 1::second);
    5::second => now;
    <<< "VISUALS: TOTAL TIME IN SECS:", (now - start) / 1::second >>>;
}


// Scene 1
spork ~ scene1Sounds(scene1, performerId);
scene1Movement(scene1, performerId);


// Scene 2
Log.print("Scene 2");
"Scene 2 - Wait" => visuals.updateText;
Utils.ramp([wind.L, wind.R], 5::second, 0.);

Log.print("Waiting for state change");
Globals.stateChange => now;


// Scene 2 --> 3 Transition
"Scene Transition - Hold tethers low" => visuals.updateText;
Globals.stateChange => now;


// Scene 3
Log.print("Scene 3");
"Scene 3 - Wait" => visuals.updateText;
Utils.ramp([vibe.L, vibe.R], 5::second, 1.);

// Reset just in case
visuals.updateLeft(-0.2, 0., -15);
visuals.updateRight(0.2, 0., -15);


// Gesture 1 - Middle performer
if (performerId == 3 || oscSender) {
    "Scene 3 - Performing" => visuals.updateText;
    spork ~ visuals.transformLeft(-0.2, 0.0, 0.5, 2::second);
    spork ~ visuals.transformRight(0.2, 0.0, 0.5, 2::second);
    2.5::second => now;

    spork ~ visuals.transformLeft(-1.5, 0.0, 0.5, 2::second);
    spork ~ visuals.transformRight(1.5, 0.0, 0.5, 2::second);
    2.5::second => now;

    spork ~ visuals.transformLeft(-0.2, 0., -15., 2::second);
    spork ~ visuals.transformRight(0.2, 0., -15., 2::second);

    // Wait for response
    2::second => now;
    "Scene 3 - Wait" => visuals.updateText;
    13::second => now;

} else {
    "Scene 3 - Wait" => visuals.updateText;
    20::second => now;
}

// Gesture 2 - Middle performer
if (performerId == 3 || oscSender) {
    "Scene 3 - Performing" => visuals.updateText;
    spork ~ visuals.transformLeft(-1.5, 0.0, 0.5, 2::second);
    spork ~ visuals.transformRight(1.5, 0.0, 0.5, 2::second);
    2.5::second => now;

    spork ~ visuals.transformLeft(-0.2, 0.0, 0.5, 2::second);
    spork ~ visuals.transformRight(0.2, 0.0, 0.5, 2::second);
    2.5::second => now;

    spork ~ visuals.transformLeft(-0.2, 0., -15., 2::second);
    spork ~ visuals.transformRight(0.2, 0., -15., 2::second);

    // Wait for response
    2::second => now;
    "Scene 3 - Wait" => visuals.updateText;
    13::second => now;

} else {
    "Scene 3 - Wait" => visuals.updateText;
    20::second => now;
}

// Gesture 3 - Side performers, 1 and 5
if (performerId == 1 || performerId == 5 || oscSender) {
    "Scene 3 - Performing" => visuals.updateText;
    spork ~ visuals.transformLeft(-1.7, 0.0, 0.5, 2::second);
    spork ~ visuals.transformRight(-1.3, 0.0, 0.5, 2::second);
    2.5::second => now;

    spork ~ visuals.transformLeft(1.3, 0.0, 0.5, 2::second);
    spork ~ visuals.transformRight(1.7, 0.0, 0.5, 2::second);
    2.5::second => now;

    spork ~ visuals.transformLeft(-0.2, 0., -15., 2::second);
    spork ~ visuals.transformRight(0.2, 0., -15., 2::second);

    // Wait for response
    2::second => now;
    "Scene 3 - Wait" => visuals.updateText;
    13::second => now;

} else {
    "Scene 3 - Wait" => visuals.updateText;
    20::second => now;
}


// Gesture 4 - Middle sides, 2 and 4
if (performerId == 2 || performerId == 4 || oscSender) {
    "Scene 3 - Performing" => visuals.updateText;
    spork ~ visuals.transformLeft(1.3, 0.0, 0.5, 2::second);
    spork ~ visuals.transformRight(1.7, 0.0, 0.5, 2::second);
    2.5::second => now;

    spork ~ visuals.transformLeft(-1.7, 0.0, 0.5, 2::second);
    spork ~ visuals.transformRight(-1.3, 0.0, 0.5, 2::second);
    2.5::second => now;

    spork ~ visuals.transformLeft(-0.2, 0., -15., 2::second);
    spork ~ visuals.transformRight(0.2, 0., -15., 2::second);

    // Wait for response
    2::second => now;
    "Scene 3 - Wait" => visuals.updateText;
    13::second => now;

} else {
    "Scene 3 - Wait" => visuals.updateText;
    20::second => now;
}


// Gesture 5 - everyone
"Scene 3 - Performing" => visuals.updateText;

spork ~ visuals.transformLeft(-1.7, 0., 0.5, 5::second);
spork ~ visuals.transformRight(-1.3, 0., 0.5, 5::second);
5::second => now;

SinOsc x(0.2) => blackhole;
SinOsc y(0.2) => blackhole;
4::second => x.period => y.period;
0.75 => x.phase;

now => time start;
while (now < start + 3::second) {
    Std.scalef(x.last(), -1., 1., -1.5, 1.5) => float x;
    Std.scalef(y.last(), -1., 1., -1.5, 1.5) => float y;

    visuals.updateLeft(x - 0.2, y, 0.5);
    visuals.updateRight(x + 0.2 , y, 0.5);
    10::ms => now;
}

"Scene 3 - Drop tether Z slightly" => visuals.updateText;
spork ~ visuals.transformLeft(-0.2, -1.5, -10, 5::second);
spork ~ visuals.transformRight(0.2, -1.5, -10, 5::second);
Log.print("Waiting for state change");
Globals.stateChange => now;


// Scene 4
Log.print("Scene 4");
"Scene 4 - Pull out tether again" => visuals.updateText;
1 => vibe.modulateSilence;

spork ~ visuals.transformLeft(-0.2, -1.5, 0.5, 5::second);
spork ~ visuals.transformRight(0.2, -1.5, 0.5, 5::second);
5::second => now;

"Scene 4 - Slow movements" => visuals.updateText;
if (performerId == 1 || performerId == 2) {
    spork ~ visuals.transformLeft(1.3, 0., 0.5, 30::second);
    spork ~ visuals.transformRight(1.7, 0., 0.5, 30::second);
    30::second => now;

    spork ~ visuals.transformLeft(-0.2, 1.5, 0.5, 30::second);
    spork ~ visuals.transformRight(0.2, 1.5, 0.5, 30::second);
    30::second => now;
} else if (performerId == 3) {
    spork ~ visuals.transformLeft(-0.2, 1.5, 0.5, 60::second);
    spork ~ visuals.transformRight(0.2, 1.5, 0.5, 60::second);
    60::second => now;

} else if (performerId == 4 || performerId == 5) {
    spork ~ visuals.transformLeft(-1.7, 0., 0.5, 30::second);
    spork ~ visuals.transformRight(-1.3, 0., 0.5, 30::second);
    30::second => now;

    spork ~ visuals.transformLeft(-0.2, 1.5, 0.5, 30::second);
    spork ~ visuals.transformRight(0.2, 1.5, 0.5, 30::second);
    30::second => now;
}

"Scene 4 - Hold" => visuals.updateText;
5::second => now;

"Scene 4 - Prepare to release" => visuals.updateText;
spork ~ visuals.countdown(5);
5::second => now;


"Scene 4 - Release tether!" => visuals.updateText;
spork ~ visuals.transformLeft(-0.2, 0., -15., 1::second);
spork ~ visuals.transformRight(0.2, 0., -15., 1::second);
5::second => now;

"End" => visuals.updateText;


Log.print("Waiting for state change");
Globals.stateChange => now;


// End
Log.print("End of piece");
