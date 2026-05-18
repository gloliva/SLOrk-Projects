public class GameTrak {
    6 => static int NUM_AXES;
    1 => static int NUM_BUTTONS;

    // AXES
    0 => static int LEFT_X;
    1 => static int LEFT_Y;
    2 => static int LEFT_Z;
    3 => static int RIGHT_X;
    4 => static int RIGHT_Y;
    5 => static int RIGHT_Z;

    // HID objects
    Hid gt;
    HidMsg msg;

    // Outs
    Step outs[7];

    // Button is after the 6 GT axes
    6 => int buttonOut;
    Event buttonPress;

    // Deadzone for Z axis
    float deadzones[2];

    // Error handling
    int _good;

    fun @construct(int device) {
        GameTrak(device, 0.04, 0.04);
    }

    fun @construct(int device, float deadzone) {
        GameTrak(device, deadzone, deadzone);
    }

    fun @construct(int device, float deadzoneL, float deadzoneR) {
        // Open GameTrak
        if (!this.gt.openJoystick(device)) return;
        1 => this._good;

        // Deadzone
        deadzoneL => this.deadzones[0];
        deadzoneR => this.deadzones[1];

        // Init outs
        for (Step out : this.outs) {
            0. => out.next;
        }

        // Run gametrak
        spork ~ this.update();
    }

    fun int good() {
        return this._good;
    }

    fun void update() {
        while (true) {
            // wait on HidIn as event
            this.gt => now;

            // messages received
            while (this.gt.recv(this.msg)) {
                // joystick axis motion
                if (this.msg.isAxisMotion()) {
                    this.msg.which => int axis;

                    // check which
                    if (axis >= 0 && axis < this.NUM_AXES) {

                        // the z axes map to [0,1], others map to [-1,1]
                        if (axis != this.LEFT_Z && axis != this.RIGHT_Z) {
                            this.msg.axisPosition => this.outs[axis].next;
                        }
                        else {
                            this.deadzones[0] => float deadzone;
                            if (axis == this.RIGHT_Z) {
                                this.deadzones[1] => deadzone;
                            }
                            Math.clampf((1 - ((this.msg.axisPosition + 1) / 2) - deadzone), 0., 1.) => this.outs[axis].next;
                        }
                    }
                }

                // Handle button presses
                if (this.msg.isButtonDown()) {
                    this.buttonPress.broadcast();
                    1. => this.outs[this.buttonOut].next;
                } else if (msg.isButtonUp()) {
                    0. => this.outs[this.buttonOut].next;
                }
            }
        }
    }
}
