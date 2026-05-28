@import "lib/globals.ck"


public class Visuals {
    GText sceneInfo;
    GText countdownInfo;
    GText leftInfo;
    GText rightInfo;
    GText idInfo;

    GPlane xAxis;
    GPlane yAxis;

    GSphere left;
    GSphere right;

    Envelope leftMovement[3];
    Envelope rightMovement[3];

    fun @construct() {
        // Setup scene
        GWindow.fullscreen();
        Color.BLACK => GG.scene().backgroundColor;

        "Waiting to start" => sceneInfo.text;
        0.25 => sceneInfo.size;
        -1.8 => sceneInfo.posY;
        @(5., 5., 5.) => sceneInfo.color;
        sceneInfo --> GG.scene();

        0.3 => countdownInfo.size;
        @(5., 5., 5.) => countdownInfo.color;

        "ID: ?" =>idInfo.text;
        0.2 => idInfo.size;
        @(-2.2, 1.8, 0.) => idInfo.pos;
        @(5., 5., 5.) => idInfo.color;
        idInfo --> GG.scene();

        "Left" => leftInfo.text;
        Color.RED => leftInfo.color;
        0.2 => leftInfo.size;
        -2.2 => leftInfo.posX;
        -1.4 => leftInfo.posY;
        leftInfo --> GG.scene();

        "Right" => rightInfo.text;
        Color.GREEN => rightInfo.color;
        0.2 => rightInfo.size;
        2.2 => rightInfo.posX;
        -1.4 => rightInfo.posY;
        rightInfo --> GG.scene();

        // Axes
        -15. => xAxis.posZ;
        -15. => yAxis.posZ;
        @(13., 0.1, 1.) => xAxis.sca;
        @(0.1, 13., 1.) => yAxis.sca;
        @(0.1, 0.1, 0.1) => xAxis.color;
        @(0.1, 0.1, 0.1) => yAxis.color;
        "X Axis" => xAxis.name;
        "Y Axis" => yAxis.name;

        xAxis --> GG.scene();
        yAxis --> GG.scene();

        // GT Tethers
        @(0.3, 0.3, 0.3) => left.sca;
        @(0.3, 0.3, 0.3) => right.sca;
        Color.RED => left.color;
        Color.GREEN => right.color;
        "Left Tether" => left.name;
        "Right Tether" => right.name;

        left --> GG.scene();
        right --> GG.scene();

        for (int i; i < leftMovement.size(); i++) {
            leftMovement[i] => blackhole;
            rightMovement[i] => blackhole;
        }

        spork ~ this.run();
    }

    fun void updateText(string text) {
        text => this.sceneInfo.text;
    }

    fun void updateId(int id) {
        "ID: " + Std.itoa(id) => idInfo.text;
    }

    fun void updateId(string id) {
        "ID: " + id => idInfo.text;
    }

    fun void countdown(int numSeconds) {
        numSeconds => int currSeconds;
        countdownInfo --> GG.scene();

        repeat(numSeconds) {
            currSeconds => Std.itoa => countdownInfo.text;
            1::second => now;
            currSeconds--;
        }

        "Now!" => countdownInfo.text;
        1::second => now;
        countdownInfo --< GG.scene();
    }

    fun void run() {
        // Main loop
        while (true) {
            GG.nextFrame() => now;

            // UI
            if (UI.begin("SLORK")) {
                // show a UI display of the current scenegraph
                UI.scenegraph(GG.scene());
            }
            UI.end();
        }
    }

    fun void updateLeft(float x, float y, float z) {
        x => leftMovement[0].value;
        y => leftMovement[1].value;
        z => leftMovement[2].value;

        @(x, y, z) => left.pos;
    }

    fun void updateRight(float x, float y, float z) {
        x => rightMovement[0].value;
        y => rightMovement[1].value;
        z => rightMovement[2].value;

        @(x, y, z) => right.pos;
    }

    fun void transformLeft(float x, float y, float z, dur d) {
        leftMovement[0].ramp(d, x);
        leftMovement[1].ramp(d, y);
        leftMovement[2].ramp(d, z);

        now => time start;

        while (now < start + d) {
            leftMovement[0].value() => left.posX;
            leftMovement[1].value() => left.posY;
            leftMovement[2].value() => left.posZ;
            GG.nextFrame() => now;
        }
    }

    fun void transformRight(float x, float y, float z, dur d) {
        rightMovement[0].ramp(d, x);
        rightMovement[1].ramp(d, y);
        rightMovement[2].ramp(d, z);

        now => time start;

        while (now < start + d) {
            rightMovement[0].value() => right.posX;
            rightMovement[1].value() => right.posY;
            rightMovement[2].value() => right.posZ;
            GG.nextFrame() => now;
        }
    }
}
