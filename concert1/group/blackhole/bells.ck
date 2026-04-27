@import "../lib/global.ck"
@import "../lib/util.ck"


// CMD line args for blackhole - is this station the OSC sender or receiver
Std.atoi(me.arg(0)) => int senderStation;


<<< "In bells, sender station", senderStation >>>;


// Globals
Global.gt @=> GameTrak @ gt;
Global.receiver @=> OscReceiver @ receiver;
Global.sender @=> OscSender @ sender;


dac.channels() => int NUM_CHANNELS;

Gain mixer[NUM_CHANNELS] => NRev rev[NUM_CHANNELS] => Envelope envs[NUM_CHANNELS] => dac;
12 => int numBells;
TubeBell bell[numBells];

for (int i; i < numBells; i++)  {
    bell[i] => mixer[i % dac.channels()];
    bell[i].opADSR(0,0.01,0.4,0.0,0.04); // short envelopes for
    bell[i].opADSR(2,0.01,0.4,0.0,0.04); // more rapid articulation
 }

TubeBell bassBell;
for (int i; i < NUM_CHANNELS; i + 2 => i) {
    bassBell => mixer[i];
}


for (int i; i < NUM_CHANNELS; i++) {
    0.5 => envs[i].gain;
    0. => envs[i].value;
}

50 => Math.mtof => bassBell.freq;

bell => Delay del => rev; // cool echo
del => del;
0.6 => del.gain;
5::second => dur T;
17*0.2::second => del.max => del.delay;


[0, 2, 3, 5, 7, 8, 10] @=> int scale[];

int pat1[0];
int pat2[0];

for (int i; i < 12; i++) {
    Math.random2(0, scale.size() -1) => int degree;
    62 + scale[degree] + (12 * Math.random2(-1, 1)) => int note;
    pat1 << note;
}

for (int i; i < 8; i++) {
    Math.random2(0, scale.size() -1) => int degree;
    62 + scale[degree] + (12 * Math.random2(0, 3)) => int note;
    pat2 << note;
}

0 => int round;
0 => int sequencing;


fun void gtHandler() {

    if (senderStation) {
        gt.buttonPress => now;
        sender.send("/enterBlackhole", 1);
        <<< "Sent OSC state change, entering blackhole" >>>;
    } else {
        1 => int waiting;
        while (waiting) {
            receiver.in => now;
            while (receiver.in.recv(receiver.msg)) {
                if (receiver.msg.address == "/enterBlackhole") {
                    0 => waiting;
                }
            }
        }
        <<< "Received OSC state change, entering blackhole" >>>;
    }
    2::second => now;

    <<< "Inside Bells, turning sound ON" >>>;
    for (Envelope env : envs) {
        env.ramp(50::ms, 1.);
        1. => bassBell.noteOn;
    }

    while (true) {
        Util.scalef(gt.axis[0], -1., 1., 0.05, 5., 0.5)::second => T;

        if (gt.axis[2] < gt.deadzone + 0.05) {
            0 => sequencing;
        } else {
            1 => sequencing;
        }

        if (gt.axis[5] < gt.deadzone) {
            0. => del.gain;
        } else {
            Math.clampf(Std.scalef(gt.axis[5], gt.deadzone, 1., 0.5, 1.), 0., 1.) => del.gain;
        }

        10::ms => now;
    }

} spork ~ gtHandler();


while (true) {

    <<< "Beginning sequencing" >>>;
    while (sequencing) {
        if (maybe) {
            <<< "Pattern 1", "" >>>;
            playPattern(pat1);
        }
        else {
            <<< "Pattern 2", "" >>>;
            playPattern(pat2);
        }
    }

    <<< "Stopping sequencing" >>>;
    while (!sequencing) {
        1::ms => now;
    }

}

fun void playPattern(int pat[])  {
    1 => int oct;
    if (maybe*maybe) {
        2 => oct; // occasional octave higher
        <<< "Octave higher", "" >>>;
    }
    for (0 => int i; i < pat.cap(); i++)  {
        if (!sequencing) break;

        Std.mtof(pat[i])*oct => bell[round].freq;
        if (i == 1 && maybe*maybe) {
            1 => bassBell.noteOn;
            <<< "Dong!", "" >>>;
        }
        1 => bell[round].noteOn;
        round++;
        if (round == numBells) 0 => round;

        now => time start;
        while (start + T > now) {
            1::ms => now;
        }
    }
}
