@import "chordProvider.ck";
@import "bpm.ck";
@import "chords.ck";
@import "../lib/gametrak.ck"
@import "../lib/global.ck"
@import "../lib/state.ck"

// Globals
Global.gt @=> GameTrak @ gt;
Global.state @=> StationState @ state;

ChordProvider t;
BPM bpm;
Chords chords;

float chordPosition;

bpm.tempo(80);
24 => chordPosition;

// let's use this four-note chord to make sure we get all four voices
chords.major @=> t.chord;

Envelope master;
1. => master.value;

Gain mix => LPF lpf => ADSR env1 => NRev reverb => Delay delay => Pan2 panLeft => Dyno limiter1 => master => dac.left;
mix => lpf => env1 => reverb => delay => Pan2 panRight => Dyno limiter2 => master => dac.right;


// Spaceship noise
CNoise noise;
noise => LPF noiseLpf(300.) => Envelope spaceshipMaster => dac;
spaceshipMaster.value(0.);
0.1 => spaceshipMaster.gain;

// waveforms setup
4 => int maxVoices;
SawOsc oscs[0];
float baseFreqs[0];
1 => float voiceGain;

// form chords
for (0 => int i; i < maxVoices; i++)
{
    SawOsc osc => mix;
    voiceGain => osc.gain;
    //enable osc sync with lfo
    2 => osc.sync; 
    oscs << osc;
    baseFreqs << 0.0;
}

// reverb setup
0.5 => reverb.mix;
0.1 => reverb.gain;

// set low pass filter
500 => lpf.freq;

// define limiter
1 => limiter1.op => limiter1.op;
3 => limiter1.ratio => limiter2.ratio;
0.2 => limiter1.thresh => limiter2.thresh;
5::ms => limiter1.attackTime => limiter2.attackTime;

// set delay
bpm.eighthNote => delay.max; //duration is a parameter. It's going to be qual to "bpm.quarterNote"
bpm.sixteenthNote => delay.delay;
delay => delay;
0.1 => delay.gain;

// define lfo
SinOsc lfo => blackhole;
0.8 => lfo.gain;
//0.1=> lfo.freq;

// global lfo frequency
float lfoFreq;

5::ms => dur T;

// right now applyLfo is only called once

// lfo modulates lpf's freq and osc freq
fun void applyLfo()
{

    500.0 => float filterCenter;
    100.0 => float filterDepth;
    1.0 => float pitchDepth;

    while (true)
    {
        lfoFreq => lfo.freq;

        // gain
        lfo.last() => float lfoValue;

        // modulate lpf's freq
        Math.max(50.0, filterCenter + filterDepth * lfoValue) => lpf.freq;

        // semitones back to freq
        Math.pow(2.0, (pitchDepth * lfoValue) / 12.0) => float pitchRatio;

        // Modulate osc freq
        for (0 => int i; i < oscs.cap(); i++)
        {
            if (baseFreqs[i] > 0 && oscs[i].gain() > 0)
            {
                baseFreqs[i] * pitchRatio => oscs[i].freq;
            }
        }

        T => now;
    }
} spork ~ applyLfo();

// initial env1 setting to mute the sounds
env1.gain(0.0);

// initial time taken for each chord
bpm.bar => dur chordTime;

fun void playChord(float position)
{
    [-12, 0, 12] @=> int offset[];

    // frequencies for this chord
    for (0 => int i; i < t.chord.cap() && i < oscs.cap(); i++)
    {
        // chordal note + random transposition + set register
        Std.mtof(t.chord[i] + offset[Math.random2(0, offset.cap() - 1)]  + position) => float baseFreq;
        baseFreq => baseFreqs[i];
        baseFreq => oscs[i].freq;
        voiceGain => oscs[i].gain;

        <<< "frequency:", t.freqToNoteName(oscs[i].freq())>>>;
    }

    Math.random2f(-1, 1) => panLeft.pan;
    Math.random2f(-1, 1) => panRight.pan;
 
    // mute any unused oscs so old notes do not ring
    for (t.chord.cap() => int i; i < oscs.cap(); i++)
    {
        0 => oscs[i].gain;
        0 => baseFreqs[i];
    }
    
    (bpm.quarterNote, bpm.quarterNote, 0.1, bpm.quarterNote) => env1.set;
    
    // triger envelope
    env1.keyOn();

    // the intial chordTime is going to keep the change slow
    chordTime => now;
}

BlowBotl bottle;
bottle => LPF lpfBottle => Chorus sound2ChorusL => NRev sound2revL => master;
bottle => lpfBottle => NRev sound2revR => master;

1000 => lpf.freq;


0 => float bottleNoteOnVal;
0 => float bottleVolume;

fun void bottleSound() {
    0.468725 => bottle.noiseGain;
    8.724864 => bottle.vibratoFreq;
    0.595734 => bottle.vibratoGain;
    bottleVolume => bottle.volume;

    Std.mtof(60) => bottle.freq;

    bottleNoteOnVal => bottle.noteOn;
}

fun void gtHandler() {
    while (true) {
        // Wait for button press
        gt.buttonPress => now;

        // Transition to next state
        state.transition();

        if (state.currState == state.SOUNDSCAPE) {
            <<< "Inside Soundscape, turning soundscape ON" >>>;
            master.ramp(5::second, 1.);
            spaceshipMaster.ramp(5::second, 0.);
        } else if (state.currState == state.STATION) {
            <<< "Inside Soundscape, turning soundscape DOWN" >>>;
            master.ramp(5::second, 0.);
            spaceshipMaster.ramp(5::second, 1.);
        } else if (state.currState == state.BLACKHOLE) {
            <<< "Inside Soundscape, transitioning to Blackhole, turning soundscape and spaceship DOWN" >>>;
            master.ramp(5::second, 0.);
            spaceshipMaster.ramp(5::second, 0.);
        }


    }
} spork ~ gtHandler();

fun void print()
{
    // time loop
    while( true )
    {
        // values
        <<< "axes:", gt.axis[0],gt.axis[1],gt.axis[2],
        gt.axis[3],gt.axis[4],gt.axis[5] >>>;
        // advance time
        100::ms => now;
    }
}

spork ~ print();

fun void axesHandler() {
    while (true) {
        // left handle's z => transposition
        (Math.round((gt.axis[2] + 1) / 2 * 7) * 12) => chordPosition;

        // left handle's y => lfo speed [-1,1] => [0,100]
        (gt.axis[1] + 1) / 2 * 50 + 0.1 => lfoFreq;
        

        // left handle's x => major/minor
        if (gt.axis[0] < -0.5) {
            chords.minor @=> t.chord;
        } else if (gt.axis[0] > 0.5) {
            chords.major @=> t.chord;
        }

        // right handle's x => tempo
        // [40, 220]
        (gt.axis[3] + 1) / 2 * 180 + 40 => bpm.tempo;

        // both handles up => sustain mode
        if (gt.axis[2] > 0.45 && gt.axis[5] > 0.45) {
            T => chordTime;
        } else {
            bpm.bar => chordTime;
        }

        // both handles down => mute
        if (gt.axis[2] < 0.005 && gt.axis[5] < 0.005) {
            // 
            env1.gain(0.0);
            0 => bottleNoteOnVal;
            bottle.noteOff(1);
        } else {
            // right handle's z => gain [-1,1] => [0,1]
            (gt.axis[5] + 1) / 2 * 3 - 1.1 => env1.gain;
            (gt.axis[5] + 1) / 4 => bottleVolume;
        }

        T => now;
    }
} spork ~ axesHandler();

// main loop
while( true )
{
    playChord(chordPosition);
    bottleSound();

    // advance time
    T => now;
}