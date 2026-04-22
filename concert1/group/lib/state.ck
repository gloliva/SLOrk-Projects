public class CaptainState {
    0 => static int NONE;
    1 => static int LEFT;
    2 => static int CENTER;
    3 => static int RIGHT;
}


public class StationState {
    // Static variables
    0 => static int SOUNDSCAPE;
    1 => static int STATION;
    2 => static int BLACKHOLE;

    3 => static int NUM_STATES;

    // Instance variables
    0 => int currState;
    0 => int hold;

    // State change event
    Event stateChange;

    fun void lock() {
        1 => this.hold;
    }

    fun void release() {
        0 => this.hold;
    }

    fun void transition() {
        if (!this.hold) {
            (this.currState + 1) % this.NUM_STATES => this.currState;
            this.stateChange.broadcast();
        }
    }
}