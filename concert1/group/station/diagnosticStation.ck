/*
This is the script for the Diagnostic personnel to run
*/

@import "../lib/gametrak.ck"
@import "../lib/global.ck"
@import "../lib/state.ck"
@import "../lib/util.ck"


// Soundscape code
Machine.add(me.dir() + "/../soundscape/main.ck");

// Globals
Global.gt @=> GameTrak @ gt;
Global.state @=> StationState @ state;


SndBuf initiating;
SndBuf toNavigator;
SndBuf toEngineers;
SndBuf toCaptain;
SndBuf checksComplete;
SndBuf systemFailure;
SndBuf failureAlarm;


Envelope masterGain;
masterGain.value(0);
0.5 => masterGain.gain;

Gain clean;
0.1 => clean.gain;
Bitcrusher distortion;
0.0 => distortion.gain;

26 => distortion.bits;
1 => distortion.downsample;

[
    initiating,
    toNavigator,
    toEngineers,
    toCaptain,
    checksComplete,
] @=> SndBuf commands[];
0 => int commandIdx;
0 => int commandsRunning;


fun void loadBuf(SndBuf myBuf, string path, float level) {
    myBuf.read(path);
    0 => myBuf.pos;
    0 => myBuf.rate; // mute the SndBuf
    myBuf.gain(level);

    myBuf => clean => masterGain => dac;
    myBuf => distortion => masterGain => dac;
}

fun void play(SndBuf myBuf) {
    0 => myBuf.pos;
    // set rate so it starts playing
    1 => myBuf.rate;
    myBuf.length() => now;
    0 => myBuf.rate;
}

fun void loopSystemFailure() {
    0.2 => failureAlarm.gain;
    1 => failureAlarm.loop;
    1. => failureAlarm.play;

    0.0 => clean.gain;
    0.1 => distortion.gain;

    24 => int numBits;
    2 => int downsampleFactor;

    while (true) {
        play(systemFailure);
        2::second => now;

        numBits => distortion.bits;
        downsampleFactor => distortion.downsample;

        if (numBits >= 3)
            numBits - 2 => numBits;

        if (downsampleFactor <= 60)
            downsampleFactor + 2 => downsampleFactor;
    }
}

public class Airlock {
    GameTrak @ gt;

    CNoise noise("white");
    Envelope thresh;
    BPF bpf;
    ADSR adsr;
    NRev rev;

    // Duration
    2000::ms => dur T;

    fun @construct(GameTrak gt, Envelope master) {
        gt @=> this.gt;

        this.noise => this.thresh => this.bpf => this.adsr => this.rev => master => dac;

        // set params
        0.05 => this.thresh.gain;
        0.2 => this.rev.mix;
        8. => this.bpf.Q;
        2. => this.adsr.gain;
        this.adsr.set(20::ms, 180::ms, 0.15, 350::ms);
    }

    fun void run() {
        while (true) {
            Math.random2(0, 2) => int kind;
            if (kind == 0) {
                this.adsr.keyOn();
                Math.random2(120, 320)::ms => now;
                this.adsr.keyOff();
                Math.random2(400, 700)::ms => now;
            } else if (kind == 1) {
                this.adsr.keyOn();
                Math.random2(500, 900)::ms => now;
                this.adsr.keyOff();
                Math.random2(500, 900)::ms => now;
            } else {
                this.adsr.keyOn();
                80::ms => now;
                this.adsr.keyOff();
                120::ms => now;
                this.adsr.keyOn();
                Math.random2(150, 300)::ms => now;
                this.adsr.keyOff();
                Math.random2(300, 600)::ms => now;
            }

            // advance time
            now => time start;
            while (start + this.T > now) {
                1::ms => now;
            }
        }
    }
}


loadBuf(initiating, me.dir() + "/../assets/initiating.wav", 0.05);
loadBuf(toNavigator, me.dir() + "/../assets/toNavigator.wav", 0.05);
loadBuf(toEngineers, me.dir() + "/../assets/toEngineer.wav", 0.05);
loadBuf(toCaptain, me.dir() + "/../assets/toPilot.wav", 0.05);
loadBuf(checksComplete, me.dir() + "/../assets/allCrewChecksComplete.wav", 0.05);
loadBuf(systemFailure, me.dir() + "/../assets/systemFailure.wav", 0.05);
loadBuf(failureAlarm, me.dir() + "/../assets/SpaceStationAlarm_HV.773.wav", 0.05);


Airlock airlock(gt, masterGain);
spork ~ airlock.run();

fun void gtHandler() {
    while (true) {
        Util.scalef(gt.axis[0], -1., 1., 150., 4000., 1.)::ms => airlock.T;
        Std.scalef(gt.axis[4], -1., 1., 200., 2000.) => airlock.bpf.freq;

        if (gt.axis[2] < gt.deadzone + 0.05) {
            airlock.thresh.ramp(50::ms, 0.);
        } else {
            airlock.thresh.ramp(50::ms, 1.);
        }

        10::ms => now;
    }
} spork ~ gtHandler();


fun void handleDiagnostics() {
    1 => int runningDiagnostics;
    while (runningDiagnostics) {
        gt.buttonPress => now;

        if (commandIdx < commands.size()) {
            play(commands[commandIdx]);
            commandIdx++;
        } else {
            spork ~ loopSystemFailure();
            0 => runningDiagnostics;
        }
    }
}


while (true) {
    // Wait for state transition
    state.stateChange => now;

    if (state.currState == state.SOUNDSCAPE) {
        <<< "Inside Diagnostic Station, transitioning to SOUNDSCAPE and turning Station OFF" >>>;
        masterGain.ramp(5::second, 0.0);
    } else if (state.currState == state.STATION) {
        <<< "Inside Diagnostic Station, turning station ON and locking state transitions" >>>;

        state.lock();
        masterGain.ramp(5::second, 1.0);
        handleDiagnostics();
        state.release();
    } else if (state.currState == state.BLACKHOLE) {
        <<< "Inside Diagnostic Station, transitioning to BLACKHOLE and turning station OFF" >>>;
        masterGain.ramp(5::second, 0.0);

        // Lock shred to prevent any more state transitions
        state.lock();

        // Add shephard generator shred + bell shred
        Machine.add(me.dir() + "/../blackhole/shephard.ck");
        Machine.add(me.dir() + "/../blackhole/bells.ck");
    }
}