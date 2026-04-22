////// STARDUST //////

@import "../lib/keyboard.ck"
@import "../lib/global.ck"
@import "../lib/util.ck"

Keyboard kb(11);
spork ~ kb.update();

Global.gt @=> GameTrak @ gt;

// decide color tint for background stardust
@(220, 230, 240)/255.0 => vec3 MANY_STARDUST_COLOR;
// set global brightness boost for stardust
5 => float STARDUST_INTENSITY;
// set spectrum radius
2.0 => float SPECTRUM_RADIUS;
// set number of small stardust particles
2000 => int STARDUST_NUM;
// establish small sphere geometry for many dots
SphereGeometry sphere_geo_many(0.017, 64, 16, 0., 2 * Math.pi, 0., Math.pi);
// per-stardust materials and parameters
FlatMaterial mat_many[STARDUST_NUM];

// initial time offset per dust
float init_time[STARDUST_NUM];
// fade in/out frequency per dust
float fade_freq[STARDUST_NUM];
// brightness per dust
float intensities[STARDUST_NUM];

// place ranges for randomization on fading frequency, the starting time, and intensity of brightness
for (int i; i < STARDUST_NUM; i++) {
    Math.random2f(0.1, 2) => fade_freq[i];
    Math.random2f(0.0, 2.0) => init_time[i];
    Math.random2f(0.1, 0.5) => intensities[i];
}

// set initial tint with slight brightness variation
for (auto x : mat_many) {
    x.color(MANY_STARDUST_COLOR * STARDUST_INTENSITY * Math.random2f(0., 0.3));
}

// instantiate min and max values per position for placing the stardusts randomly
GMesh stardusts[STARDUST_NUM];
-40 => float minX => float minY;
-100 => float minZ;
40 => float maxX => float maxY;
100 => float maxZ;
(maxX - minX) * 0.5 => float maxXDistance;
(maxZ - minZ) * 0.5 => float maxZDistance;

// minimum radius from the origin to keep particles outside the waterfall ring
SPECTRUM_RADIUS * 2 => float STARDUST_MIN_R;

// place the stardusts in the scene
for (int i; i < STARDUST_NUM; i++) {
    GMesh sphere(sphere_geo_many, mat_many[i]);
    sphere @=> stardusts[i];
    stardusts[i] --> GG.scene();

    float x, y, z;
    0 => int placed;

    while (placed == 0) {
        //assign a value within the min-max range to the pos of stardust
        Math.random2f(minX, maxX) => x;
        Math.random2f(minY, maxY) => y;
        Math.random2f(minZ, maxZ) => z;
        // compare to the minimum radius that keep the particulars toward the outer ring
        if (Math.sqrt(x*x + y*y) >= STARDUST_MIN_R) 
            //placement completed
            1 => placed;
    }

    @(x, y, z) => stardusts[i].translate;
}

// animate stardust's fading and drifting
fun void fade_in_out() {
    now => time init_t;

    while (true) {
        GG.nextFrame() => now;
        (now - init_t) / 1::second => float t;

        for (int i; i < STARDUST_NUM; i++) {
            // define color and brightness every frame with some randomness
            MANY_STARDUST_COLOR * STARDUST_INTENSITY * intensities[i] * Math.fabs(Math.sin(fade_freq[i] * t + init_time[i])) => mat_many[i].color;
        }
    }
} spork ~ fade_in_out();

int wKeyDown, aKeyDown, sKeyDown, dKeyDown;
fun void kbState() {
    while (true) {
        // wait for kb event
        kb.event => now;

        if (kb.event.state == KeyboardEvent.DOWN && kb.event.key == "W".charAt(0)) {
            true => wKeyDown;
        } else if (kb.event.state == KeyboardEvent.UP && kb.event.key == "W".charAt(0)) {
            false => wKeyDown;
        }

        if (kb.event.state == KeyboardEvent.DOWN && kb.event.key == "A".charAt(0)) {
            true => aKeyDown;
        } else if (kb.event.state == KeyboardEvent.UP && kb.event.key == "A".charAt(0)) {
            false => aKeyDown;
        }

        if (kb.event.state == KeyboardEvent.DOWN && kb.event.key == "S".charAt(0)) {
            true => sKeyDown;
        } else if (kb.event.state == KeyboardEvent.UP && kb.event.key == "S".charAt(0)) {
            false => sKeyDown;
        }

        if (kb.event.state == KeyboardEvent.DOWN && kb.event.key == "D".charAt(0)) {
            true => dKeyDown;
        } else if (kb.event.state == KeyboardEvent.UP && kb.event.key == "D".charAt(0)) {
            false => dKeyDown;
        }
    }
} spork ~ kbState();

fun void kbHandler() {
    1 => float speed;
    while (true) {
        GG.nextFrame() => now;

        if (wKeyDown) {
            GG.camera().posZ(GG.camera().posZ() - speed);
        }
        if (aKeyDown) {
            GG.camera().posX(GG.camera().posX() - speed / 2);
        }
        if (sKeyDown) {
            GG.camera().posZ(GG.camera().posZ() + speed);
        }
        if (dKeyDown) {
            GG.camera().posX(GG.camera().posX() + speed / 2);
        }
    }
} spork ~ kbHandler();

fun float easeInOutCubic(float x) {
    return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
}

Shred @ stopShred;
float deltaX, deltaZ;

fun void stop() {
    while (Math.fabs(deltaX) > 0.001 || Math.fabs(deltaZ) > 0.001) {
        GG.nextFrame() => now;

        Util.lerp(deltaX, 0, 0.05) => deltaX;
        Util.lerp(deltaZ, 0, 0.05) => deltaZ;

        GG.camera().posZ(GG.camera().posZ() + deltaZ);
        GG.camera().posX(GG.camera().posX() + deltaX);
    }
    0.0 => deltaX => deltaZ;
    null @=> stopShred;
}


fun void gtHandler() {
    2 => float maxSpeed;
    0.05 => float zThreshold;

    while (true) {
        GG.nextFrame() => now;

        if (gt.axis[5] < zThreshold) {
            if ((deltaX != 0 || deltaZ != 0) && stopShred == null) spork ~ stop() @=> stopShred;
            continue;
        }

        Math.sgn(gt.axis[3]) * easeInOutCubic(Math.fabs(gt.axis[3])) => float easedX;
        Math.sgn(gt.axis[4]) * easeInOutCubic(Math.fabs(gt.axis[4])) => float easedY;

        Math.map2(easedX, -1, 1, -maxSpeed, maxSpeed) / 2 => deltaX;
        Math.map2(easedY, -1, 1, maxSpeed / 4, -maxSpeed) => deltaZ;

        GG.camera().posZ(GG.camera().posZ() + deltaZ);
        GG.camera().posX(GG.camera().posX() + deltaX);
    }
} spork ~ gtHandler();

fun int allKeysUp() { return !wKeyDown && !aKeyDown && !sKeyDown && !dKeyDown; }
fun int allKeysDown() { return wKeyDown && aKeyDown && sKeyDown && dKeyDown; }

// for infinite space
fun void translateStars() {
    while (true) {
        GG.nextFrame() => now;

        // if (allKeysUp() || allKeysDown()) continue;

        for (auto stardust : stardusts) {
            if (Math.fabs(stardust.posZ() - GG.camera().posZ()) > maxZDistance) {
                if (gt.axis[4] > 0) stardust.translateZ(-maxZDistance * 2);
                else stardust.translateZ(maxZDistance * 2);

                if (wKeyDown) stardust.translateZ(-maxZDistance * 2);
                else if (sKeyDown) stardust.translateZ(maxZDistance * 2);
            }
            if (Math.fabs(stardust.posX() - GG.camera().posX()) > maxXDistance) {
                if (gt.axis[3] < 0) stardust.translateX(-maxXDistance * 2);
                else stardust.translateX(maxXDistance * 2);

                if (aKeyDown) stardust.translateX(-maxXDistance * 2);
                else if (dKeyDown) stardust.translateX(maxXDistance * 2);
            }
        }
    }
} spork ~ translateStars();

while (true) {
    GG.nextFrame() => now;
}