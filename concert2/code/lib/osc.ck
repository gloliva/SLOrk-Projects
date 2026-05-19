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
        // Sends in loop, spork this function
        while (true) {
            this.out.start(addr);
            this.out.add(val);
            this.out.send();
            50::ms => now;
        }
    }
}


public class OscReceiver {
    6449 => static int DEFAULT_PORT;

    OscIn in;
    OscMsg msg;

    // State management
    Event @ stateChange;
    int currState;

    fun @construct(Event stateChange) {
        stateChange @=> this.stateChange;
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
                if (this.msg.address == "/state") {
                    this.msg.getInt(0) => int state;
                    if (state > this.currState) {
                        this.stateChange.broadcast();
                        state => this.currState;
                    }
                }
            }
        }
    }
}