public class GameTrak {
    // HID objects
    Hid trak;
    HidMsg msg;

    // timestamps
    time lastTime;
    time currTime;

    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];

    // button down/up state
    int buttonState;
    Event buttonPress;

    // z axis deadzone
    0.008 => static float DEADZONE;

    // axes
    0 => static int X;
    1 => static int Y;
    2 => static int Z;

    fun @construct(int device) {
        // open joystick 0, exit on fail
        if( !this.trak.openJoystick( device ) ) me.exit();
        <<< "joystick '" + this.trak.name() + "' ready" >>>;
    }

    // gametrack handling
    fun void run() {
        while( true )
        {
            // wait on HidIn as event
            trak => now;

            // messages received
            while( trak.recv( msg ) )
            {
                // joystick axis motion
                if( msg.isAxisMotion() )
                {
                    // check which
                    if( msg.which >= 0 && msg.which < 6 )
                    {
                        // check if fresh
                        if( now > this.currTime )
                        {
                            // time stamp
                            this.currTime => this.lastTime;
                            // set
                            now => this.currTime;
                        }
                        // save last
                        this.axis[msg.which] => this.lastAxis[msg.which];
                        // the z axes map to [0,1], others map to [-1,1]
                        if( msg.which != 2 && msg.which != 5 )
                        { msg.axisPosition => this.axis[msg.which]; }
                        else
                        {
                            1 - ((msg.axisPosition + 1) / 2) - this.DEADZONE => this.axis[msg.which];
                            if( this.axis[msg.which] < 0 ) 0 => this.axis[msg.which];
                        }
                    }
                }

                // joystick button down
                else if( msg.isButtonDown() )
                {
                    1 => this.buttonState;
                    this.buttonPress.signal();
                }

                // joystick button up
                else if( msg.isButtonUp() )
                {
                    0 => this.buttonState;
                }
            }
        }
    }
}
