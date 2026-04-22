@import "../lib/gametrak.ck"
@import "../lib/state.ck"
@import "../lib/snd.ck"
@import "../lib/util.ck"
@import "../lib/global.ck"

Global.gt @=> GameTrak @ gt;

CaptainState.NONE => int state;

SndBuf phone(me.dir() + "../assets/phone.wav") => Gain phoneGain => dac;
phone.loop(true);
phoneGain.gain(0);

SndBuf radio(me.dir() + "../assets/radio.wav") => Gain radioGain => dac;
radio.loop(true);
radioGain.gain(0);

SndBuf engineBuf(me.dir() + "../assets/engineThrust.wav") => LPF engineLPF => HPF engineHPF => Gain engineGain => PoleZero blocker => dac;
engineBuf.loop(true);
0 => engineGain.gain;
2000. => engineLPF.freq;
0.5 => engineLPF.Q;
50 => engineHPF.freq;
0.5 => engineHPF.Q;
.95 => blocker.blockZero;

0.05 => float engineDeadzone;
0.05 => float engineZThreshold;

CNoise engineNoise("white") => LPF engineFilter => NRev engineRev => Gain engineNoiseGain => dac;
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

        zEnv * curGain => engineGain.gain;
        curRate => engineBuf.rate;
        tgtLPF => engineLPF.freq;

        Std.scalef(magnitude, 0, 1, 80, 500) => engineFilter.freq;
        zEnv * curved * 0.15 => engineNoiseGain.gain;

        10::ms => now;
    }
} spork ~ engineUpdate();

-0.5 => float leftThreshold;
0.5 => float rightThreshold;
0.2 => float centerThreshold;
0.3 => float zThreshold;

int walkieTalkie;
Shred @ startWTShred;
Shred @ loopWTShred;

fun void gtHandler() {
    while (true) {
        // x axis
        if (gt.axis[0] < leftThreshold && gt.axis[2] >= zThreshold) CaptainState.LEFT => state;
        else if (gt.axis[0] > rightThreshold && gt.axis[2] >= zThreshold) CaptainState.RIGHT => state;
        else if (gt.axis[0] > -centerThreshold && gt.axis[0] < centerThreshold) CaptainState.CENTER => state;

        // z axis
        if (gt.axis[2] >= zThreshold && !walkieTalkie) {
            true => walkieTalkie;
            spork ~ Snd.play(me.dir() + "../assets/start-walkie-talkie.wav") @=> startWTShred;
            spork ~ Snd.loop(me.dir() + "../assets/walkie-talkie.wav", 0.5) @=> loopWTShred;
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
            Math.map2(gt.axis[0], leftThreshold, -1, 0, 1) => phoneGain.gain;
        } else if (state == CaptainState.RIGHT) {
            Math.map2(gt.axis[0], rightThreshold, 1, 0, 3) => radioGain.gain;
        }

        10::ms => now;
    }
} spork ~ stateHandler();

while (true) {
    10::ms => now;
}