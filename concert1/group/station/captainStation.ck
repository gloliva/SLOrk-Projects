@import {"../blackhole/shephard.ck", "../blackhole/bells.ck"}
@import {"../lib/gametrak.ck", "../lib/keyboard.ck", "../lib/osc.ck"}
@import {"../lib/global.ck", "../lib/state.ck", "../lib/snd.ck", "../lib/util.ck"}
@import "../soundscape/paulstretch.ck"


// Soundscape code
Machine.add(me.dir() + "/../soundscape/main.ck");


// Globals variables
Global.gt @=> GameTrak @ gt;
Global.state @=> StationState @ stationState;

// OSC handling
OscSender sender;
OscReceiver receiver(Events.damageStation, Events.stateChange, Events.shepardReverse, Events.stationFadeOut);

// State management
CaptainState.NONE => int state;
Envelope masterGain => dac;

// Warp + Blackhole objects
ShepardGenerator sg(gt);
BlackholeBells bells(gt);



SndBuf phone(me.dir() + "../assets/phone.wav") => Gain phoneGain => Delay phoneDelay => masterGain;
phone.loop(true);
phoneGain.gain(0);

2::second => phoneDelay.max;
0.0::second => phoneDelay.delay;


SndBuf radio(me.dir() + "../assets/radio.wav") => Gain radioGain => Delay radioDelay => masterGain;
radio.loop(true);
radioGain.gain(0);

2::second => radioDelay.max;
0.0::second => radioDelay.delay;


SndBuf engineBuf(me.dir() + "../assets/engineThrust.wav") => LPF engineLPF => HPF engineHPF => Gain engineGain => Delay engineDelay => PoleZero blocker => masterGain;
engineBuf.loop(true);
0 => engineGain.gain;
2000. => engineLPF.freq;
0.5 => engineLPF.Q;
50 => engineHPF.freq;
0.5 => engineHPF.Q;
.95 => blocker.blockZero;

2::second => engineDelay.max;
0.0::second => engineDelay.delay;


0.03 => float engineDeadzone;
0.03 => float engineZThreshold;

CNoise engineNoise("white") => LPF engineFilter => NRev engineRev => Gain engineNoiseGain => masterGain;
0 => engineNoiseGain.gain;
0.08 => engineRev.mix;
100. => engineFilter.freq;

// setting up PS for in blackhole sound stretch
PaulStretch phonePS;
phonePS.useInput(phone);
phonePS.setResolution(0.5); // smaller => more extreme

PaulStretch radioPS;
radioPS.useInput(radio);
radioPS.setResolution(0.5);

PaulStretch enginePS;
enginePS.useInput(engineBuf);
enginePS.setResolution(0.5);


fun void engineUpdate() {
    0.0 => float curGain;
    1.0 => float curRate;
    0.0 => float zEnv;

    while (true) {
        gt.axis[4] => float y;
        Math.fabs(y) => float magnitude;
        if (magnitude < engineDeadzone) 0 => magnitude;
        Math.sqrt(magnitude) => float curved;

        0.0 => float tgtGain;
        curRate => float tgtRate;
        2000. => float tgtLPF;
        if (y > 0 && magnitude > 0) {
            curved => tgtGain;
            0.9 + 0.5 * magnitude => tgtRate;
            Std.scalef(magnitude, 0, 1, 1200, 4000) => tgtLPF;
        } else if (y < 0 && magnitude > 0) {
            curved * 0.9 => tgtGain;
            -(0.5 + 0.35 * magnitude) => tgtRate;
            Std.scalef(magnitude, 0, 1, 500, 1600) => tgtLPF;
        }

        0.0 => float zTarget;
        if (gt.axis[5] > engineZThreshold) 1.0 => zTarget;

        Util.lerp(curGain, tgtGain, 0.2) => curGain;
        Util.lerp(curRate, tgtRate, 0.2) => curRate;
        Util.lerp(zEnv, zTarget, 0.025) => zEnv;

        zEnv * curGain => engineGain.gain;
        curRate => engineBuf.rate;
        tgtLPF => engineLPF.freq;

        Std.scalef(magnitude, 0, 1, 80, 500) => engineFilter.freq;
        zEnv * curved * 0.15 => engineNoiseGain.gain;

        10::ms => now;
    }
}

//spork ~ engineUpdate();

Shred @ engineShred;
spork ~ engineUpdate() @=> engineShred;

-0.5 => float leftThreshold;
0.5 => float rightThreshold;
0.2 => float centerThreshold;
0.3 => float zThreshold;

int walkieTalkie;
Shred @ startWTShred;
Shred @ loopWTShred;

fun void kbHandler() {
    // Setup keyboard
    Util.getKeyboardDeviceId() => int keyboardId;
    Keyboard kb(keyboardId);

    while (true) {
        kb.event => now;

        if (kb.event.state == KeyboardEvent.DOWN) {
            kb.event.key - "0".charAt(0) => int stationId;
            if (stationId > 0 && stationId < 6 ) {
                <<< "Sending OSC:", stationId >>>;
                sender.send("/damage", stationId);
            }

            if (kb.event.data == Keyboard.SPACE_BAR) {
                sg.reverse();
            }
        }
    }
} spork ~ kbHandler();

fun void gtHandler() {
    while (true) {
        // x axis
        if (gt.axis[0] < leftThreshold && gt.axis[2] >= zThreshold) CaptainState.LEFT => state;
        else if (gt.axis[0] > rightThreshold && gt.axis[2] >= zThreshold) CaptainState.RIGHT => state;
        else if (gt.axis[0] > -centerThreshold && gt.axis[0] < centerThreshold) CaptainState.CENTER => state;

        // z axis
        if (gt.axis[2] >= zThreshold && !walkieTalkie) {
            true => walkieTalkie;
            spork ~ Snd.play(me.dir() + "../assets/start-walkie-talkie.wav", 0.5, masterGain) @=> startWTShred;
            spork ~ Snd.loop(me.dir() + "../assets/walkie-talkie.wav", 0.25, masterGain) @=> loopWTShred;
        } else if (gt.axis[2] < zThreshold && walkieTalkie) {
            false => walkieTalkie;
            if (startWTShred != null) startWTShred.exit();
            if (loopWTShred != null) loopWTShred.exit();
        }

        10::ms => now;
    }
} spork ~ gtHandler();

fun void stateHandler() {
    while (true) {
        if (state == CaptainState.LEFT) {
            Math.map2(gt.axis[0], leftThreshold, -1, 0, 0.3) => phoneGain.gain;
        } else if (state == CaptainState.RIGHT) {
            Math.map2(gt.axis[0], rightThreshold, 1, 0, 1) => radioGain.gain;
        }

        10::ms => now;
    }
}

spork ~ stateHandler();

// --------------------Fade Back--------------------//

SinOsc lfo => blackhole;
0.8 => lfo.gain;
0.5 => lfo.freq;

BPF fadeBackBpf;
NRev fadeBackRev;
Delay fadeBackDelay;
Dyno limit;
limit.limit();


// lfo modulates bpf's freq
fun void applyLfo()
{
    1000.0 => float filterCenter;
    200.0 => float filterDepth;
    // 1.0 => float pitchDepth;

    while (true)
    {
        // gain
        lfo.last() => float lfoValue;

        // modulate lpf's freq
        Math.max(50.0, filterCenter + filterDepth * lfoValue) => fadeBackBpf.freq;
        <<< "Modulating", fadeBackBpf.freq >>>;
        5::ms => now;
    }
}


fun void fadeBack() {
    // wait for 10 seconds
    20::second => dur fadeBackDur;

    fadeBackDur => now;

    // ramp back in volume
    masterGain.ramp(fadeBackDur, 1.);

    // quit engine shred to avoid fighting with volume control 
    if (engineShred != null) engineShred.exit();
    // we can also quit the handler shred thus fix the volumes
    // if (stateHandlerShred != null) stateHandlerShred.exit();


    // reverse playbacks
    phone.samples() => phone.pos;
    -1. => phone.rate;

    radio.samples() => radio.pos;
    -1. => radio.rate;

    engineBuf.samples() => engineBuf.pos;
    -1. => engineBuf.rate;

    // activate effects
    1.0::second => fadeBackDelay.max;
    0.5::second => fadeBackDelay.delay;

    0.5 => fadeBackRev.gain;
    0.5 => fadeBackRev.mix;

    1000 => fadeBackBpf.freq;
    1 => fadeBackBpf.Q;

    // reroute
    masterGain =< dac;
    masterGain => fadeBackBpf => fadeBackDelay => fadeBackRev => limit => dac;

    // modulate this BPF
    spork ~ applyLfo();

    // PS route
    
    // phonePS.start();
    // phonePS.out().gain(0.1);
    // phonePS.out() => masterGain;
}


fun void shepardHandler() {
    Events.shepardReverse => now;
    sg.reverse();
} spork ~ shepardHandler();


fun void sendStateChange(string addr) {
    while (true) {
        sender.send(addr, 1);
        50::ms => now;
    }
}


// Handle program transitions
while (true) {
    // Wait for state transition
    gt.buttonPress => now;
    stationState.transition();

    if (stationState.currState == stationState.STATION && !stationState.hold) {
        // Send state change OSC
        spork ~ sendStateChange("/state/station");

        // Turn off soundscape sounds
        MasterGain.soundscape.ramp(5::second, 0.);

        // Turn on station sounds
        MasterGain.spaceship.ramp(5::second, 1.);
        masterGain.ramp(5::second, 1.0);
    } else if (stationState.currState == stationState.WARP && !stationState.hold) {
        // Send state change OSC
        spork ~ sendStateChange("/state/warp");

        // Turn off station sounds
        MasterGain.spaceship.ramp(5::second, 0.);
        masterGain.ramp(5::second, 0.0);

        // Turn on Shepard tone
        spork ~ sg.gtHandler();
    } else if (stationState.currState == stationState.BLACKHOLE && !stationState.hold) {
        spork ~ sendStateChange("/state/blackhole");

        // Cut Shepard Tone and turn on Bells
        spork ~ sg.stopSound();
        spork ~ bells.run();

        // Lock shred to prevent any more state
        stationState.lock();

        fadeBack();
    }
}