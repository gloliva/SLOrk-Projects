@import "../lib/gametrak.ck"
@import "../lib/global.ck"
@import "../lib/keyboard.ck"
@import "../lib/osc.ck"
@import "../lib/state.ck"
@import "../lib/util.ck"


// cmd line args to assign station ID
Std.atoi(me.arg(0)) => int senderStation;
Std.atoi(me.arg(1)) => int stationId;


// Soundscape code
Machine.add(me.dir() + "/../soundscape/main.ck");


// State
Global.gt @=> GameTrak @ gt;
Global.receiver @=> OscReceiver @ receiver;
Global.state @=> StationState @ state;


public class Station {
    // Keyboard handling
    int keyIdx;
    Keyboard @ kb;
    TriOsc keySounds[12];
    ADSR envs[12];

    // OSC handling
    OscReceiver @ receiver;
    int stationId;

    // scale
    [0, 3, 7, 10, 13] @=> int scale[];

    // State
    int damaged;

    // Alarm sound
    SndBuf alarm;
    SndBuf damageSounds[2];

    CNoise crash("pink");
    ADSR crashEnv;
    NRev crashRev;

    Envelope machineRate;

    // Fixing buffers
    int repairIdx;
    SndBuf repairSounds[6];
    SndBuf fixedSound;

    fun @construct(Envelope master[], Envelope machineRate, OscReceiver receiver, int stationId) {
        machineRate @=> this.machineRate;
        receiver @=> this.receiver;
        stationId => this.stationId;

        // Setup keyboard clicking sound
        for (int i; i < this.keySounds.size(); i++) {
            this.keySounds[i] @=> TriOsc osc;
            this.envs[i] @=> ADSR env;

            osc => env => master[(i % dac.channels())];
            0.2 => osc.gain;
            env.set(25::ms, 80::ms, 0.7, 100::ms);

            // set freq
            Math.random2(0, this.scale.size()) => int note;
            Math.mtof(60 + (Math.random2(-2, 2) * 12) + note) => osc.freq;
        }

        // Set sound buffers
        me.dir() + "../assets/SpaceStationAlarm_HV.773.wav" => alarm.read;

        me.dir() + "../assets/SpaceshipAirlockClose_HV._2.wav" => damageSounds[0].read;
        me.dir() + "../assets/SciFiWeapon_S08SF.1677.wav" => damageSounds[1].read;

        me.dir() + "../assets/SteampunkDevice_S011SF.739.wav" => repairSounds[0].read;
        me.dir() + "../assets/SteampunkDevice_S011SF.744.wav" => repairSounds[1].read;
        me.dir() + "../assets/SteampunkDevice_S011SF.752.wav" => repairSounds[2].read;
        me.dir() + "../assets/SteampunkDevice_S011SF.758.wav" => repairSounds[3].read;
        me.dir() + "../assets/SteampunkDevice_S011SF.759.wav" => repairSounds[4].read;
        me.dir() + "../assets/SteampunkDevice_S011SF.752.wav" => repairSounds[5].read;

        me.dir() + "../assets/SciFiWeapon_S08SF.1677.wav" => fixedSound.read;

        0.7 => crash.gain;
        crash => crashEnv => crashRev => master;
        crashEnv.set(25::ms, 250::ms, 0.5, 3::second);

        alarm => master;
        0.2 => alarm.gain;
        0 => alarm.play;

        // Crash sound
        for (int i; i < damageSounds.size(); i++) {
            0 => damageSounds[i].play;
            0.1 => damageSounds[i].gain;
            damageSounds[i] => master;
        }
        0.3 => damageSounds[1].gain;

        for (int i; i < this.repairSounds.size(); i++) {
            0 => repairSounds[i].play;
            0.2 => repairSounds[i].gain;
            repairSounds[i] => master[(i % dac.channels())];
        }

        fixedSound => master;
        0.05 => fixedSound.gain;
        fixedSound.samples() => fixedSound.pos;
        0 => fixedSound.play;

        // Setup keyboard
        Util.getKeyboardDeviceId() => int keyboardId;
        new Keyboard(keyboardId) @=> this.kb;
    }

    fun void oscListen() {
        while (true) {
            this.receiver.in => now;
            while (this.receiver.in.recv(this.receiver.msg)) {
                if (this.receiver.msg.address == "/damage" && this.receiver.msg.getInt(0) == this.stationId) {
                    if (!this.damaged) {
                        this.machineRate.ramp(5::second, 0.);
                        this.damage();
                    }
                }
            }
        }
    }

    fun void damage() {
        1 => this.damaged;

        // Play crash sound
        playCrash();

        // Play damage sounds
        0 => damageSounds[1].pos;
        1. => damageSounds[1].play;
        8::second => now;

        // Play alarm sounds
        0 => alarm.pos;
        1 => alarm.loop;
        1 => alarm.play;
    }

    fun void playKeyboardSound() {
        this.envs[this.keyIdx].keyOn(1);
        100::ms => now;
        this.envs[this.keyIdx].keyOff(1);
        (this.keyIdx + 1) % this.envs.size() => this.keyIdx;
    }

    fun void playKeyboardSound2() {
        0 => this.repairSounds[repairIdx].pos;
        this.repairSounds[repairIdx].play(1);
        (repairIdx + 1) % this.repairSounds.size() => repairIdx;
    }

    fun void playCrash() {
        crashEnv.keyOn(1);
        3::second => now;
        crashEnv.keyOff(1);
    }

    fun void interact(Envelope master[]) {
        while (true) {
            this.kb.event => now;

            // Check if adjusting volume
            if (this.kb.event.state == KeyboardEvent.DOWN && this.kb.event.data == Keyboard.UP_ARROW) {
                for (Envelope env : master) {
                    env.ramp(20::second, 1.);
                }
            } else if (this.kb.event.state == KeyboardEvent.DOWN && this.kb.event.data == Keyboard.DOWN_ARROW) {
                for (Envelope env : master) {
                    env.ramp(5::second, 0.);
                }
            }

            // Check if repairing station
            if (this.damaged) {
                if (this.kb.event.state == KeyboardEvent.DOWN && this.kb.event.key == "R".charAt(0)) {
                    this.repair();
                    machineRate.ramp(5::second, 1.) => now;
                } else {
                    // Play keyboard clicking sounds
                    spork ~ this.playKeyboardSound();
                    spork ~ this.playKeyboardSound2();
                }
            }
        }
    }

    fun void repair() {
        0 => this.damaged;

        0 => alarm.loop;
        0 => alarm.play;

        fixedSound.samples() => fixedSound.pos;
        -1 => fixedSound.play;

        0 => damageSounds[0].pos;
        2. => damageSounds[0].play;
    }
}


Envelope master[6];
PoleZero blocker[6];
for (int i; i < master.size(); i++) {
    0.95 => blocker[i].blockZero;
    master[i] => blocker[i] => dac.chan(i % dac.channels());
}


SndBuf2 buf1(me.dir() + "../assets/ElectricHum_BW.44833.wav");
SndBuf2 buf2(me.dir() + "../assets/SciFiWorkshop_S08SF.1719.wav");

1 => buf1.loop;
1 => buf2.loop;

buf1 => Gain gains[2];
buf2 => gains;

0.1 => gains[0].gain;
0.1 => gains[1].gain;

gains[0] => NRev revL;
gains[1] => NRev revR;

// Connect to Hemis
revL => master[0];
revL => master[2];
revL => master[4];
revR => master[1];
revR => master[3];
revR => master[5];


buf1.play(1.);
buf2.play(1.);


Envelope machineRate => blackhole;
1. => machineRate.value;


fun void updateMachinery() {
    while (true) {
        machineRate.value() => buf2.play;
        10::ms => now;
    }
} spork ~ updateMachinery();


// Initialize repair station and enable keyboard interaction
Station station(master, machineRate, receiver, stationId);
spork ~ station.interact(master);
spork ~ station.oscListen();


while (true) {
    // Wait for state transition
    state.stateChange => now;

    if (state.currState == state.SOUNDSCAPE) {
        <<< "Inside Repair Station, turning Station OFF" >>>;
        for (Envelope env : master) {
            env.ramp(5::second, 0.);
        }
    } else if (state.currState == state.STATION) {
        <<< "Inside Repair Station, doing nothing for now..." >>>;
    } else if (state.currState == state.BLACKHOLE) {
        for (Envelope env : master) {
            env.ramp(5::second, 0.);
        }

        // Lock shred to prevent any more state transitions
        state.lock();

        // Add shephard generator shred + bell shred
        Machine.add(me.dir() + "/../blackhole/shephard.ck");
        Machine.add(me.dir() + "/../blackhole/bells.ck:" + senderStation);
    }
}
