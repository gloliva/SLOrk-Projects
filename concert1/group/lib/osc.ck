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

    fun @construct() {
        OscReceiver(this.DEFAULT_PORT);
    }

    fun @construct(int port) {
        port => this.in.port;
        this.in.listenAll();
    }
}
