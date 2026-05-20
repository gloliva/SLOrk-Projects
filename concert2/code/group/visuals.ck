@import "../lib/globals.ck"


// Setup scene
8. => GG.scene().camera().posZ;
GG.scene().camera().orthographic();
Color.BLACK => GG.scene().backgroundColor;


public class Visuals {
    GText sceneInfo;
    GText leftInfo;
    GText rightInfo;

    GSphere left;
    GSphere right;

    Envelope leftMovement[3];
    Envelope rightMovement[3];

    fun @construct() {
        "Waiting to start" => sceneInfo.text;
        0.25 => sceneInfo.size;
        -1.8 => sceneInfo.posY;
        @(5., 5., 5.) => sceneInfo.color;
        sceneInfo --> GG.scene();

        "Left" => leftInfo.text;
        Color.RED => leftInfo.color;
        0.2 => leftInfo.size;
        -2. => leftInfo.posX;
        -1.8 => leftInfo.posY;
        leftInfo --> GG.scene();

        "Right" => rightInfo.text;
        Color.GREEN => rightInfo.color;
        0.2 => rightInfo.size;
        2. => rightInfo.posX;
        -1.8 => rightInfo.posY;
        rightInfo --> GG.scene();

        @(0.3, 0.3, 0.3) => left.sca;
        @(0.3, 0.3, 0.3) => right.sca;
        Color.RED => left.color;
        Color.GREEN => right.color;

        left --> GG.scene();
        right --> GG.scene();

        for (int i; i < leftMovement.size(); i++) {
            leftMovement[i] => blackhole;
            rightMovement[i] => blackhole;
        }

        spork ~ this.stateHandler();
        spork ~ this.run();
    }

    fun void stateHandler() {
        Globals.stateChange => now;
        "Scene 1" => sceneInfo.text;

        Globals.stateChange => now;
        "Scene 2 - No movement" => sceneInfo.text;

        Globals.stateChange => now;
        "Scene 3" => sceneInfo.text;

        Globals.stateChange => now;
        "Scene 4" => sceneInfo.text;
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
        @(x, y, z) => left.pos;

        x => leftMovement[0].value;
        y => leftMovement[1].value;
        z => leftMovement[2].value;
    }

    fun void updateRight(float x, float y, float z) {
        @(x, y, z) => right.pos;

        x => rightMovement[0].value;
        y => rightMovement[1].value;
        z => rightMovement[2].value;
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
