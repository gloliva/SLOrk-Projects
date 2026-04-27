@import "gametrak.ck"
@import "osc.ck"
@import "state.ck"

public class Global {
    static GameTrak gt(0);
    static OscReceiver receiver;
    static OscSender sender;
    static StationState state;
}