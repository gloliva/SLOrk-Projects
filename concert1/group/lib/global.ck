@import "gametrak.ck"
@import "osc.ck"
@import "state.ck"


// Global events and variables
public class Events {
    static DamageStationEvent damageStation;
    static Event stateChange;
}

public class Global {
    static GameTrak gt(0);
    static StationState state;
}

public class MasterGain {
    static Envelope soundscape;
    static Envelope spaceship;
}
