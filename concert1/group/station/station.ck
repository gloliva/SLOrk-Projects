@import {"../blackhole/shephard.ck", "../blackhole/bells.ck"}
@import {"../lib/gametrak.ck", "../lib/keyboard.ck", "../lib/osc.ck"}
@import {"../lib/global.ck", "../lib/state.ck", "../lib/util.ck"}


// Soundscape code
Machine.add(me.dir() + "/../soundscape/main.ck");


// Globals
Global.gt @=> GameTrak @ gt;
Global.state @=> StationState @ stationState;
OscReceiver receiver(Events.damageStation, Events.stateChange, stationState.stateChange);

Std.atoi(me.arg(0)) => int sound;
Std.atoi(me.arg(1)) => int testRun;

@(0.0, 0.0) => vec2 sound1Gain;
@(0.0, 0.0) => vec2 sound2Gain;
@(0.0, 0.0) => vec2 sound3Gain;
sound == 4 ? @(0.01, 0.01) : @(0.0, 0.0) => vec2 sound4Gain;
sound == 5 ? @(0.01, 0.01) : @(0.0, 0.0) => vec2 sound5Gain;

int navigator;
if (sound == 5) true => navigator;

// --------------------- GAINS --------------------- //
[
    sound1Gain,
    sound2Gain,
    sound3Gain,
    sound4Gain,
    sound5Gain,
] @=> vec2 levels[];

Gain gainsLeft[0];
Gain gainsRight[0];
for (int i; i < levels.size(); i++) {
    gainsLeft << new Gain(levels[i].x);
    gainsRight << new Gain(levels[i].y);
}

Envelope masterGain;
masterGain.value(0);

// Connect gains to DAC (this is bad, be better)
dac.channels() => int numChans;
for (int i; i < gainsLeft.size(); i++) {
    for (int c; c + 1 < numChans; 2 +=> c) {
        gainsLeft[i] => masterGain => dac.chan(c);
        gainsRight[i] => masterGain => dac.chan(c + 1);
    }
}

// -------------------- SOUND 2 -------------------- //
BlowBotl bottle;
bottle => Chorus sound2ChorusL => NRev sound2revL => gainsLeft[1];
bottle => NRev sound2revR => gainsRight[1];

fun void sound2() {
    0.468725 => bottle.noiseGain;
    8.724864 => bottle.vibratoFreq;
    0.595734 => bottle.vibratoGain;
    0.702008 => bottle.volume;

    Std.mtof(60) => bottle.freq;

    while (true) {

        .8 => bottle.noteOn;

        // advance time
        1::second => now;
    }
} spork ~ sound2();

// -------------------- SOUND 3 -------------------- //
BlowHole hole => ADSR beep => gainsLeft[2];
beep => gainsRight[2];

beep.set(35::ms, 50::ms, 0.7, 100::ms);

0.742307 => hole.reed;
0.862736 => hole.noiseGain;
0.642372 => hole.tonehole;
0.051535 => hole.vent;
0.250131 => hole.pressure;
80 => hole.freq;
0.8 => hole.noteOn;

750 => int beepRate;
fun void sound3(dur initDelay) {
    initDelay => now;
    while (true) {
        beep.keyOn(1);
        100::ms => now;
        beep.keyOff(1);
        beepRate::ms => now;
    }
} spork ~ sound3(750::ms);


// -------------------- SOUND 4 -------------------- //
CNoise sound4Noise("white");
sound4Noise => BPF sound4Bpf => ADSR sound4Env => NRev sound4Rev => gainsLeft[3];
sound4Env => NRev sound4RevR => gainsRight[3];
0.2 => sound4Rev.mix;
0.2 => sound4RevR.mix;
8. => sound4Bpf.Q;
3. => sound4Env.gain;

fun void sound4() {
    sound4Env.set(20::ms, 180::ms, 0.15, 350::ms);
    while (true) {
        Math.random2f(350., 1400.) => sound4Bpf.freq;
        Math.random2(0, 2) => int kind;
        if (kind == 0) {
            sound4Env.keyOn();
            Math.random2(120, 320)::ms => now;
            sound4Env.keyOff();
            Math.random2(400, 700)::ms => now;
        } else if (kind == 1) {
            sound4Env.keyOn();
            Math.random2(500, 900)::ms => now;
            sound4Env.keyOff();
            Math.random2(500, 900)::ms => now;
        } else {
            sound4Env.keyOn();
            80::ms => now;
            sound4Env.keyOff();
            120::ms => now;
            sound4Env.keyOn();
            Math.random2(150, 300)::ms => now;
            sound4Env.keyOff();
            Math.random2(300, 600)::ms => now;
        }
        Math.random2(1200, 3500)::ms => now;
    }
} spork ~ sound4();


// -------------------- SOUND 5 -------------------- //
PoleZero blocker;
.95 => blocker.blockZero;

SinOsc pingOsc => LPF pingLpf => ADSR pingEnv => Gain pingDry;
pingDry => NRev pingRev => blocker => gainsLeft[4];
pingDry => NRev pingRevR => blocker =>  gainsRight[4];

pingDry => DelayL pingDelay => LPF pingFbLpf => Gain pingFb => pingDelay;
pingDelay => pingRev;
pingDelay => pingRevR;

3::second => pingDelay.max;
200::ms => pingDelay.delay;
1800. => pingFbLpf.freq;
0.45 => pingFb.gain;

4200. => pingLpf.freq;
0.15 => pingRev.mix;
0.15 => pingRevR.mix;
0.65 => pingEnv.gain;
pingEnv.set(2::ms, 5::ms, 0.6, 12::ms);

4000::ms => dur pingPeriod;
40::ms => dur pingHold;


fun void sound5() {
    while (true) {
        Math.random2f(1250., 1300.) => pingOsc.freq;
        pingEnv.keyOn();
        pingHold => now;
        pingEnv.keyOff();

        now => time start;
        while (start + pingPeriod > now) {
            10::ms => now;
        }
    }
} spork ~ sound5();

fun void sound5Delay() {
    pingDelay.delay() => dur current;
    while (true) {
        Std.scalef(gt.axis[1], -1., 1., 100., 300.)::ms => dur target;
        if (Math.fabs((target - current) / 1::ms) > 15.) {
            target => pingDelay.delay;
            target => current;
        }
        60::ms => now;
    }
} spork ~ sound5Delay();


float origL[levels.size()];
float origR[levels.size()];
for (int i; i < levels.size(); i++) {
    levels[i].x => origL[i];
    levels[i].y => origR[i];
}

fun void applySound(int sel) {
    for (int i; i < levels.size(); i++) {
        if (sel == 0 || sel - 1 == i) {
            origL[i] => gainsLeft[i].gain;
            origR[i] => gainsRight[i].gain;
        } else {
            0. => gainsLeft[i].gain;
            0. => gainsRight[i].gain;
        }
    }
}


// Gametrack effects
fun void gtHandler() {
    while (true) {
        Std.scalef(gt.axis[0], -1., 1., 250., 5000.)::ms => pingPeriod;
        Std.scalef(gt.axis[1], -1., 1., 30, 1000) $ int => beepRate;
        Std.scalef(gt.axis[0], -1., 1., 200., 2000.) => sound4Bpf.freq;

        if (gt.axis[2] < gt.deadzone) {
            0. => pingEnv.gain;
        } else {
            Std.scalef(gt.axis[2], gt.deadzone, 0.4, 0., 1.) => pingEnv.gain;
        }

        10::ms => now;
    }
} spork ~ gtHandler();

PoleZero blocker2;
.95 => blocker2.blockZero;

SndBuf engineBuf(me.dir() + "../assets/engineThrust.wav") => LPF engineLPF => HPF engineHPF => Gain engineGain => blocker2 => masterGain;
engineBuf.loop(true);
0 => engineGain.gain;
2000. => engineLPF.freq;
0.5 => engineLPF.Q;
50 => engineHPF.freq;
0.5 => engineHPF.Q;

0.03 => float engineDeadzone;
0.03 => float engineZThreshold;

CNoise engineNoise("white") => LPF engineFilter => NRev engineRev => Gain engineNoiseGain => masterGain;
0 => engineNoiseGain.gain;
0.08 => engineRev.mix;
100. => engineFilter.freq;

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

        zEnv * curGain * 0.1 => engineGain.gain;
        curRate => engineBuf.rate;
        tgtLPF => engineLPF.freq;

        Std.scalef(magnitude, 0, 1, 80, 500) => engineFilter.freq;
        zEnv * curved * 0.15 * 0.1 => engineNoiseGain.gain;

        10::ms => now;
    }
}

if (navigator) spork ~ engineUpdate();


fun void warpHandler() {
    while (true) {
        gt.buttonPress => now;

        // Each station handles their own STATION --> WARP transition
        if (stationState.currState == stationState.STATION && !stationState.hold) {
            Events.stateChange.broadcast();
            break;
        }
    }
} spork ~ warpHandler();


// Warp + Blackhole objects
ShepardGenerator sg(gt);
BlackholeBells bells(gt);


while (true) {
    // Wait for state transition
    if (!testRun) {
        Events.stateChange => now;
    } else {
        gt.buttonPress => now;
    }
    stationState.transition();

    if (stationState.currState == stationState.STATION && !stationState.hold) {
        <<< "Inside Navigator, turning Navigator ON" >>>;
        masterGain.ramp(5::second, 1.0);
    } else if (stationState.currState == stationState.WARP && !stationState.hold) {
        // Turn off station sounds
        masterGain.ramp(5::second, 0.0);

        // Turn on Shepard tone
        spork ~ sg.gtHandler();
    } else if (stationState.currState == stationState.BLACKHOLE && !stationState.hold) {
        // Cut Shepard Tone and turn on Bells
        spork ~ sg.stopSound();
        spork ~ bells.run();

        // Lock shred to prevent any more state
        stationState.lock();
    }
}
