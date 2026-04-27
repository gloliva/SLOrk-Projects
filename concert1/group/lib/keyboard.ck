public class KeyboardEvent extends Event {
    0 => static int DOWN;
    1 => static int UP;

    int key;
    int data;
    int state;

    fun void set(int key, int data, int state) {
        key => this.key;
        data => this.data;
        state => this.state;
    }
}

public class Keyboard {
    Hid hi;
    HidMsg msg;
    KeyboardEvent event;

    // Static variables
    82 => static int UP_ARROW;
    81 => static int DOWN_ARROW;

    fun @construct(int device) {
        if( !this.hi.openKeyboard( device ) ) {
            cherr <= "Error opening Keyboard device with ID " <= device <= IO.nl();
            me.exit();
        }
        <<< "keyboard '" + this.hi.name() + "' ready", "" >>>;

        spork ~ this.update();
        me.yield();
    }

    fun void update() {
        while( true ) {
            // wait on event
            this.hi => now;

            // get one or more messages
            while( this.hi.recv( this.msg ) ) {
                // check for action type
                if( this.msg.isButtonDown() ) {
                    this.event.set(this.msg.ascii, this.msg.which, this.event.DOWN);
                    this.event.broadcast();

                } else {
                    this.event.set(this.msg.ascii, this.msg.which, this.event.UP);
                    this.event.broadcast();
                }
            }
        }
    }
}
