#include FRAME_UNIFORMS
#include DRAW_UNIFORMS
#include STANDARD_VERTEX_INPUT

const PI: f32 = 3.1415926538;
const HFOV: f32 = 2.0;
const DISK_BRIGHTNESS: f32 = 1.0;
const DISK_COLOR: vec3f = vec3f(1.0, 0.8, 0.6);
const TAN_HALF_HFOV: f32 = 1.5574077246549023;  // tan(HFOV / 2) = tan(1.0)

struct VertexOutput {
    @builtin(position) position : vec4f,
    @location(0) v_uv : vec2f,
};

@group(1) @binding(0) var u_texture : texture_2d<f32>;      // background panorama
@group(1) @binding(1) var<uniform> u_pos : vec3f;           // camera position
@group(1) @binding(4) var u_noise_texture : texture_2d<f32>; // accretion disk noise
@group(1) @binding(5) var<uniform> u_radius : f32;
@group(1) @binding(9) var<uniform> u_bg_alpha : f32;         // 0 = show bg, 1 = discard bg
@group(1) @binding(12) var u_sampler : sampler;              // linear+repeat

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    var u_Draw: DrawUniforms = u_draw_instances[in.instance];
    let worldpos = u_Draw.model * vec4f(in.position, 1.0f);
    out.position = (u_frame.projection * u_frame.view) * worldpos;
    out.v_uv = in.uv;
    return out;
}

fn rotate(vel: vec3f, turn: vec2f) -> vec3f {
    let cx = cos(turn.x); let sx = sin(turn.x);
    let cy = cos(turn.y); let sy = sin(turn.y);
    let pitchRot = mat3x3f(
        vec3f(1., 0., 0.),
        vec3f(0., cy, -sy),
        vec3f(0., sy,  cy)
    );
    let yawRot = mat3x3f(
        vec3f( cx, 0., sx),
        vec3f( 0., 1., 0.),
        vec3f(-sx, 0., cx)
    );
    return normalize(yawRot * pitchRot * vel);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    if (u_radius < 0.005 && u_bg_alpha > 0.99) {
        discard;
    }
    let uv = 2. * in.v_uv - 1;

    var vel = normalize(vec3f(uv * TAN_HALF_HFOV, -1.0));

    // Layered reality warp — 3 sequential rotations driven by (1 - bg_alpha).
    let warp = 1. - u_bg_alpha;
    let tw = u_frame.time;

    let flow = vec2f(
        sin(tw * 0.22 + uv.x * 1.3 + uv.y * 0.6) * 0.07,
        cos(tw * 0.19 + uv.y * 1.1 - uv.x * 0.8) * 0.07
    ) * warp;
    vel = rotate(vel, flow);

    let phi_uv = atan2(uv.y, uv.x);
    let rho_uv = length(uv);
    let spiral = sin(tw * 0.15 + rho_uv * 1.2) * 0.05 * warp;
    vel = rotate(vel, vec2f(-spiral * sin(phi_uv), spiral * cos(phi_uv)));

    vel = rotate(vel, vec2f(sin(tw * 0.08) * 0.04 * warp,
                            cos(tw * 0.11) * 0.03 * warp));

    vel = vec3f(vel.z, vel.xy);

    let dist = length(u_pos);
    var pos = vec3f(u_pos.z, u_pos.xy);
    var r = length(pos);
    let dtau = 0.008;

    let disk_inner_radius = u_radius + 0.1;
    let disk_outer_radius = u_radius * 2.5;
    var disk_rgb = vec3f(0.);
    var get_disk = false;

    var inside_bh: bool = false;
    var step_count: i32 = 0;

    let noise_dim_f = vec2f(textureDimensions(u_noise_texture));
    let u_radius_sq = u_radius * u_radius;
    var min_r: f32 = r;

    while ((r < dist * 2. || r < 20.) && step_count < 500) {
        step_count = step_count + 1;

        let ddtau = dtau * max(0.2, r);
        pos += vel * ddtau;

        let r_sq = dot(pos, pos);
        let inv_r = inverseSqrt(r_sq);
        r = r_sq * inv_r;
        min_r = min(min_r, r);

        if (r_sq <= u_radius_sq) {
            inside_bh = true;
            break;
        }

        if (r > disk_inner_radius && r < disk_outer_radius) {
            let disk_height = abs(pos.z);
            if (disk_height < 0.01 && !get_disk) {
                let phi = 5. * atan2(vel.z, vel.x) / PI;
                let local_uv = fract(vec2f(phi, 0.));
                let coords = vec2i(local_uv * noise_dim_f);
                disk_rgb = textureLoad(u_noise_texture, coords, 0).rgb;
                disk_rgb = smoothstep(vec3f(-2.), vec3f(0.9), disk_rgb);
                disk_rgb *= DISK_COLOR * DISK_BRIGHTNESS;
                disk_rgb *= smoothstep(disk_inner_radius, disk_outer_radius, r) * smoothstep(disk_outer_radius, disk_inner_radius, r);
                get_disk = true;
            }
        }

        if (r > 0.01) {
            let er = pos * inv_r;
            let vdote = dot(vel, er);
            let vel_sq = dot(vel, vel);
            let dot_c_c = vel_sq - vdote * vdote;
            vel -= (ddtau * dot_c_c * inv_r * inv_r) * er;
        }
    }

    // Spherical coords for background lookup.
    let phi1 = 0.5 + atan2(vel.y, vel.x) / PI;
    let theta1 = atan2(length(vel.xy), vel.z) / PI;

    let UV = fract(vec2f(phi1, theta1));
    var rgb = textureSampleLevel(u_texture, u_sampler, UV, 0.).rgb;
    rgb = pow(rgb, vec3f(2.4));

    let echo_UV = fract(vec2f(theta1 + 0.37, phi1 + 0.21));
    var rgb_echo = textureSampleLevel(u_texture, u_sampler, echo_UV, 0.).rgb;
    rgb_echo = pow(rgb_echo, vec3f(2.4));
    rgb = rgb + rgb_echo * (warp * 0.28);

    // Halo bleed-through during approach.
    let halo_gate = smoothstep(0.02, 0.15, u_radius);
    let eff_r = max(0.05, u_radius);
    let halo = smoothstep(eff_r * 5., eff_r * 1.5, min_r) * halo_gate;
    let bg_alpha_eff = u_bg_alpha * (1. - halo);

    if (!inside_bh && !get_disk && bg_alpha_eff > 0.999) {
        discard;
    }
    let bg = rgb * f32(!inside_bh) * (1. - bg_alpha_eff);
    return vec4f(disk_rgb + bg, 1.0);
}
