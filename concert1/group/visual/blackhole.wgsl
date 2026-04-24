#include FRAME_UNIFORMS
// will include the following:
// struct FrameUniforms {
//     projection: mat4x4f,                     // 4x4 projection matrix, used to transform from camera space to clip space.
//     view: mat4x4f,                           // 4x4 view matrix, used to transform from world space to camera space.
//     projection_view_inverse_no_translation: mat4x4f, // Inverse of the combined projection and view matrices, but without translation. Useful for certain non-world-space calculations (e.g., ray casting).
//     camera_pos: vec3f,                       // Position of the camera in world space.
//     time: f32,                               // Time elapsed (likely in seconds), useful for animations or time-dependent effects.
//     ambient_light: vec3f,                    // RGB color for the ambient light in the scene.
//     num_lights: i32,                         // Number of active lights in the scene.
//     background_color: vec4f,                 // RGBA color of the background.
// };
// @group(0) @binding(0) var<uniform> u_frame: FrameUniforms;

#include DRAW_UNIFORMS
// will include the following:
// struct DrawUniforms {
//     model: mat4x4f,                          // 4x4 model matrix, transforms from object space to world space for this instance.
//     id: u32                                  // Unique identifier for the draw instance, often used for object-specific effects or picking.
// };
// Each instance of a drawable object gets its own DrawUniforms entry.
// @group(2) @binding(0) var<storage> u_draw_instances: array<DrawUniforms>;

#include STANDARD_VERTEX_INPUT
// struct VertexInput {
//     @location(0) position : vec3f,           // Vertex position in object space, read from vertex buffer at location 0.
//     @location(1) normal : vec3f,             // Vertex normal vector, used for lighting calculations, read from vertex buffer at location 1.
//     @location(2) uv : vec2f,                 // Texture coordinates (UV mapping), read from vertex buffer at location 2.
//     @builtin(instance_index) instance : u32, // Built-in variable for the instance index, identifying which instance of the object is being rendered.
// };

#include STANDARD_VERTEX_OUTPUT
// struct VertexOutput {
//     @builtin(position) position : vec4f,     // Built-in variable for the clip-space position of the vertex, used for rasterization.
//     @location(0) v_worldpos : vec3f,         // World-space position of the vertex, passed to the fragment shader for effects like lighting.
//     @location(1) v_normal : vec3f,           // World-space normal vector, passed to the fragment shader for lighting calculations.
//     @location(2) v_uv : vec2f,               // Interpolated texture coordinates, passed to the fragment shader for sampling textures.
// };

const PI: f32 = 3.1415926538;

@group(1) @binding(0) var u_texture : texture_2d<f32>;  // background texture
@group(1) @binding(1) var<uniform> u_pos : vec3f;       // camera position
@group(1) @binding(2) var<uniform> u_rotation : vec2f;  // blackhole rotation
@group(1) @binding(3) var<uniform> u_view_turn : vec2f;  // view turn determined by mouse movement
@group(1) @binding(4) var u_noise_texture : texture_2d<f32>;  // noise texture for accretion disk
@group(1) @binding(5) var<uniform> u_radius : f32;  // blackhole radius
@group(1) @binding(6) var<uniform> u_hfov : f32;
@group(1) @binding(7) var<uniform> u_disk_brightness : f32;  // disk brightness
@group(1) @binding(8) var<uniform> u_disk_color : vec3f;  // disk color
@group(1) @binding(9) var<uniform> u_bg_alpha : f32;  // 0 = show star bg, 1 = discard bg (stardust shows through)
@group(1) @binding(12) var u_sampler : sampler;         // linear+repeat, for smooth bg texture sampling
@group(1) @binding(13) var<uniform> u_warp_boost : f32; // 1.0 baseline; spikes high during "dimensional tearing" pulses

// standard vertex shader that applies mvp transform to input position,
// and passes interpolated world_position, normal, and uv data to fragment shader
@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    var u_Draw: DrawUniforms = u_draw_instances[in.instance];

    let worldpos = u_Draw.model * vec4f(in.position, 1.0f);

    out.position = (u_frame.projection * u_frame.view) * worldpos;
    out.v_worldpos = worldpos.xyz;
    out.v_normal = (u_Draw.model * vec4f(in.normal, 0.0)).xyz;
    out.v_uv = in.uv;

    return out;
}


// Function to compute an anti-aliased checkerboard pattern.
fn checkerAA(p: vec2f) -> f32 {
    let q = sin(PI * p * vec2f(10.0, 10.0));  // Create a sine pattern with periodicity in x and y directions.
    let m = q.x * q.y;                       // Combine the sine waves to create a checkerboard effect.
    // return 0.5 - m / fwidth(m);              // Apply anti-aliasing using the derivative of the function.
    // return step(0., m);
    return smoothstep(0., fwidth(m), m);
}

fn linearstep(A: f32, B: f32, X: f32) -> f32 {
    let t = (X - A) / (B - A);
    return clamp(t, 0., 1.);
}

fn rotate(vel: vec3f, turn: vec2f) -> vec3f {
    let pitchRot = mat3x3f(
        vec3f(1., 0., 0.),
        vec3f(0., cos(turn.y), -sin(turn.y)),
        vec3f(0., sin(turn.y), cos(turn.y))
    );

    let yawRot = mat3x3f(
        vec3f(cos(turn.x), 0., sin(turn.x)),
        vec3f(0., 1., 0.),
        vec3f(-sin(turn.x), 0., cos(turn.x))
    );

    return normalize(yawRot * pitchRot * vel);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    // Early-out: nothing to draw when the BH is "off" (radius 0 + bg hidden).
    // Lets the stardust-mode script keep the plane attached with no flash.
    if (u_radius < 0.005 && u_bg_alpha > 0.99) {
        discard;
    }
    let uv = 2. * in.v_uv - 1;

    // this is the vel of the ray shooting from the camera to the fragment
    var vel = normalize(vec3f(uv * tan(u_hfov / 2.0), -1.0));
    vel = rotate(vel, u_view_turn);

    // Layered reality warp. Gated off when u_bg_alpha=1 (approach mode) so the
    // stardust phase stays calm. Each layer contributes a *different kind* of
    // distortion — combined they feel less like jitter and more like physics
    // being bent: spacetime billowing, views turning in on themselves, cosmos
    // slowly drifting. Low frequencies throughout for a flowing sensation.
    // PERF: combine all three warp layers into a single rotate() call.
    // Each layer is a small-angle perturbation (|angle| < 0.1 rad), so
    // composition-order error is O(0.01 rad) — invisible. Also skip the
    // whole block when warp contribution is essentially zero (early approach
    // frames where u_bg_alpha is still near 1).
    let warp = 1. - u_bg_alpha;
    let tw = u_frame.time;
    if (warp > 0.01) {
        let tb = u_warp_boost;  // 1.0 baseline; dimensional-tearing pulses multiply everything
        let flow = vec2f(
            sin(tw * 0.22 + uv.x * 1.3 + uv.y * 0.6) * 0.07 * tb,
            cos(tw * 0.19 + uv.y * 1.1 - uv.x * 0.8) * 0.07 * tb
        );
        let phi_uv = atan2(uv.y, uv.x);
        let rho_uv = length(uv);
        let spiral = sin(tw * 0.15 + rho_uv * 1.2) * 0.05 * tb;
        let drift = vec2f(sin(tw * 0.08) * 0.04 * tb, cos(tw * 0.11) * 0.03 * tb);
        let total = (flow + vec2f(-spiral * sin(phi_uv), spiral * cos(phi_uv)) + drift) * warp;
        vel = rotate(vel, total);
    }

    vel = vec3f(vel.z, vel.xy);

    // Initialize the position of the particle or camera.
    // let dist = 5.;
    // var pos = vec3f(-dist, 1.0, 0.0);
    let dist = length(u_pos);
    var pos = vec3f(u_pos.z, u_pos.xy);
    var r = length(pos);                      // Distance from the origin.
    let dtau = 0.008;                           // Step size for iteration.

    // accretion disk — wider than physically minimal so lensed rays that
    // cross z=0 at r slightly past the traditional 2.5*Rs boundary still
    // register, giving the visible ring more reach (this is what produces
    // the curving top/bottom lobes from a distance).
    let disk_inner_radius = u_radius + 0.1;
    let disk_outer_radius = max(u_radius * 6.0, 4.0);  // wider annulus — rings reach further out
    var disk_rgb = vec3f(0.);
    var get_disk = false;

    var inside_bh: bool = false;

    let max_reach = max(dist * 2., 20.);
    let noise_dim_f = vec2f(textureDimensions(u_noise_texture));

    // IMPACT-PARAMETER FAST PATH.
    // Rays whose straight-line closest approach to the BH is large get no
    // meaningful lensing, so skip the raymarch: direct texture lookup, no
    // chromatic aberration. Threshold scales with u_bg_alpha so during
    // approach (camera far, BH small on screen) more rays take the slow
    // path and the rings render correctly. In BH mode the threshold is
    // tight (4) for perf.
    let b_main = length(cross(pos, vel));
    // Threshold must be at least the disk outer radius so every ray that
    // could hit the disk annulus goes through the slow path. Also widens
    // during approach (u_bg_alpha high) so distant ring rays still render.
    let b_threshold = max(disk_outer_radius + 1., mix(6., 14., u_bg_alpha));
    if (b_main >= b_threshold) {
        var disk_direct = vec3f(0.);
        if (abs(vel.z) > 0.001) {
            let t_cross = -pos.z / vel.z;
            if (t_cross > 0.) {
                let pos_cross = pos + t_cross * vel;
                let r_cross = length(pos_cross);
                if (r_cross > disk_inner_radius && r_cross < disk_outer_radius) {
                    let phi = 5. * atan2(vel.z, vel.x) / PI;
                    let local_uv = fract(vec2f(phi, 0.) - u_rotation * 2.);
                    let coords = vec2i(local_uv * noise_dim_f);
                    disk_direct = textureLoad(u_noise_texture, coords, 0).rgb;
                    disk_direct = smoothstep(vec3f(-2.), vec3f(0.9), disk_direct);
                    disk_direct *= u_disk_color * u_disk_brightness;
                    disk_direct *= smoothstep(disk_inner_radius, disk_outer_radius, r_cross)
                                 * smoothstep(disk_outer_radius, disk_inner_radius, r_cross);
                }
            }
        }

        let phi1_d  = 0.5 + atan2(vel.y, vel.x) / PI;
        let theta1_d = atan2(length(vel.xy), vel.z) / PI;
        let UV_d = fract(vec2f(phi1_d, theta1_d) - u_rotation);
        var rgb_d = textureSampleLevel(u_texture, u_sampler, UV_d, 0.).rgb;
        rgb_d = pow(rgb_d, vec3f(2.4));

        let has_disk = (disk_direct.r + disk_direct.g + disk_direct.b) > 0.001;
        if (!has_disk && u_bg_alpha > 0.999) { discard; }
        return vec4f(disk_direct + rgb_d * (1. - u_bg_alpha), 1.0);
    }

    // Track how far the ray travels off the disk plane so edge-on rays
    // (which would paint a horizontal stripe across the BH) are excluded
    // from disk shading — only lensed-over-the-BH rays register.
    var max_abs_z: f32 = abs(pos.z);
    var min_r: f32 = r;

    // Capture threshold as squared radius — the early-exit capture check
    // avoids a sqrt.
    let u_radius_sq = u_radius * u_radius;

    // Persistent reciprocal from inverseSqrt — reused for gravity.
    var inv_r: f32 = 1.0 / max(r, 0.0001);

    var step_count: i32 = 0;
    loop {
        if (!(r < max_reach) || step_count >= 500) { break; }
        step_count = step_count + 1;

        let ddtau = dtau * max(0.2, r);
        pos += vel * ddtau;

        // One rsqrt gives r AND 1/r together.
        let r_sq = dot(pos, pos);
        inv_r = inverseSqrt(r_sq);
        r = r_sq * inv_r;

        min_r = min(min_r, r);
        max_abs_z = max(max_abs_z, abs(pos.z));

        // Capture.
        if (r_sq <= u_radius_sq) { inside_bh = true; break; }

        // Disk (lensed-weight gate keeps the edge-on stripe invisible).
        if (r > disk_inner_radius && r < disk_outer_radius) {
            let prev_z = pos.z - vel.z * ddtau;
            let crossed = prev_z * pos.z < 0.;
            let disk_height = abs(pos.z);
            if (disk_height < 0.03 || crossed) {
                let lensed_weight = smoothstep(0.15, 0.6, max_abs_z);
                let phi = 5. * atan2(vel.z, vel.x) / PI;
                let local_uv = fract(vec2f(phi, 0.) - u_rotation * 2.);
                let coords = vec2i(local_uv * noise_dim_f);
                var new_disk = textureLoad(u_noise_texture, coords, 0).rgb;
                new_disk = smoothstep(vec3f(-2.), vec3f(0.9), new_disk);
                new_disk *= u_disk_color * u_disk_brightness * lensed_weight;
                new_disk *= smoothstep(disk_inner_radius, disk_outer_radius, r)
                          * smoothstep(disk_outer_radius, disk_inner_radius, r);
                disk_rgb = max(disk_rgb, new_disk);
                get_disk = true;
            }
        }

        // Gravity (cross+dot identity, inverseSqrt-derived reciprocals).
        if (r > 0.01 && r < 25.) {
            let er = pos * inv_r;
            let vdote = dot(vel, er);
            let dot_c_c = dot(vel, vel) - vdote * vdote;
            vel -= (ddtau * dot_c_c * inv_r * inv_r) * er;
        }
    }

    // Calculate spherical coordinates for texture mapping.
    let phi1 = 0.5 + (atan2(vel.y, vel.x) / (PI)) ; // Azimuthal angle, normalized to (0,1)
    let theta1 = atan2(length(vel.xy), vel.z) / PI; // Polar angle., normalized to (0,1)

    // UV coordinates for the texture.
    let UV = fract(vec2f(phi1, theta1) - u_rotation);
    let bh_commit = 1. - u_bg_alpha;

    // Chromatic aberration (phi split), BH-mode only, scales with warp_boost.
    let eff_r_ca = max(0.15, u_radius);
    let aberration = smoothstep(eff_r_ca * 4., eff_r_ca * 1.5, min_r) * bh_commit * 0.006 * u_warp_boost;
    var rgb: vec3f;
    if (aberration > 0.0005) {
        let UV_r = fract(vec2f(phi1 + aberration, theta1) - u_rotation);
        let UV_b = fract(vec2f(phi1 - aberration, theta1) - u_rotation);
        rgb = vec3f(
            textureSampleLevel(u_texture, u_sampler, UV_r, 0.).r,
            textureSampleLevel(u_texture, u_sampler, UV,   0.).g,
            textureSampleLevel(u_texture, u_sampler, UV_b, 0.).b
        );
    } else {
        rgb = textureSampleLevel(u_texture, u_sampler, UV, 0.).rgb;
    }
    rgb = pow(rgb, vec3f(2.4));

    // Dimensional echo: only sample when the warp is actually contributing.
    let warp_now = 1. - u_bg_alpha;
    if (warp_now > 0.01) {
        let echo_UV = fract(vec2f(theta1 + 0.37, phi1 + 0.21) - u_rotation * 1.5);
        var rgb_echo = textureSampleLevel(u_texture, u_sampler, echo_UV, 0.).rgb;
        rgb_echo = pow(rgb_echo, vec3f(2.4));
        rgb = rgb + rgb_echo * (warp_now * 0.28);
    }

    // Rays that passed close to any BH get their lensed-background contribution
    // bled in even when u_bg_alpha is high — this is the visible "halo" around
    // a BH during approach, so the captain sees the full lensing outline long
    // before commit to BH mode. Rays that went nowhere near a BH still discard.
    // Gate halo on actual radius: prevents the smoothstep from degenerating
    // (and from leaking light through) when the BH is still fading in.
    let halo_gate = smoothstep(0.02, 0.15, u_radius);
    let eff_r = max(0.05, u_radius);
    let halo = smoothstep(eff_r * 5., eff_r * 1.5, min_r) * halo_gate;
    let bg_alpha_eff = u_bg_alpha * (1. - halo);

    if (!inside_bh && !get_disk && bg_alpha_eff > 0.999) {
        discard;
    }
    // Gate disk contribution on capture: a ray that eventually gets swallowed
    // by the event horizon still accumulated disk_rgb while passing through
    // the annulus on its way in. Adding that back to the final color would
    // paint the disk through the BH silhouette (a solid line cutting across
    // the black disc). Captured rays should read pure black; the disk only
    // colors rays that actually escape to infinity and passed through the
    // annulus along the way — which gives the correct "disk curves around
    // the top and bottom, BH interior is black" appearance.
    let visible = f32(!inside_bh);
    let bg = rgb * visible * (1. - bg_alpha_eff);
    let rgb_final = disk_rgb * visible + bg;
    return vec4f(rgb_final, 1.0);
}
