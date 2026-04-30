public class OscSender {
    "255.255.255.255" => static string BROADCAST_HOST;
    6449 => static int DEFAULT_PORT;

    OscOut out;

    fun @construct() {
        OscSender(this.BROADCAST_HOST, this.DEFAULT_PORT);
    }

    fun @construct(string host, int port) {
        this.out.dest(host, port);
    }

    fun send(string addr, int val) {
        this.out.start(addr);
        this.out.add(val);
        this.out.send();
    }

}


public class OscReceiver {
    6449 => static int DEFAULT_PORT;

    OscIn in;
    OscMsg msg;

    // Events
    DamageStationEvent @ damageStation;
    Event @ stateChange;
    Event @ shepardReverse;
    Event @ stationFadeOut;

    fun @construct(DamageStationEvent damageStation, Event stateChange, Event shepardReverse, Event stationFadeOut) {
        damageStation @=> this.damageStation;
        stateChange @=> this.stateChange;
        shepardReverse @=> this.shepardReverse;
        stationFadeOut @=> this.stationFadeOut;
        OscReceiver(this.DEFAULT_PORT);
    }

    fun @construct(int port) {
        port => this.in.port;
        this.in.listenAll();
        spork ~ this.listen();
    }

    fun void listen() {
        while (true) {
            this.in => now;
            while (this.in.recv(this.msg)) {
                <<< "Addr:", this.msg.address, "Value:", this.msg.getInt(0) >>>;
                if (this.msg.address == "/damage") {
                    this.msg.getInt(0) => this.damageStation.stationId;
                    this.damageStation.broadcast();
                } else if (this.msg.address == "/state/station" || this.msg.address == "/state/blackhole") {
                    this.stateChange.broadcast();
                } else if (this.msg.address == "/state/warp") {
                    this.stationFadeOut.broadcast();
                } else if (this.msg.address == "/shepard/reverse") {
                    this.shepardReverse.broadcast();
                }
            }
        }
    }
}


// Custom OSC Events
public class DamageStationEvent extends Event {
    int stationId;
}
