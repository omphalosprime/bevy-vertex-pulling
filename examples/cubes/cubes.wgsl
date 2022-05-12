struct View {
    view_proj: mat4x4<f32>;
    view: mat4x4<f32>;
    inverse_view: mat4x4<f32>;
    projection: mat4x4<f32>;
    world_position: vec3<f32>;
    near: f32;
    far: f32;
    width: f32;
    height: f32;
};

struct Cube {
    center: vec4<f32>;
    half_extents: vec4<f32>;
    color: vec4<f32>;
};

struct Cubes {
    data: array<Cube>;
};

[[group(0), binding(0)]]
var<uniform> view: View;

[[group(1), binding(0)]]
var<storage> cubes: Cubes;

struct VertexOutput {
    [[builtin(position)]] clip_position: vec4<f32>;
    [[location(0)]] world_position: vec4<f32>;
    [[location(1)]] world_normal: vec3<f32>;
    [[location(2)]] uvw: vec3<f32>;
    [[location(3)]] color: vec4<f32>;
    [[location(4)]] raydir: vec3<f32>;
    [[location(5)]] cube_center: vec3<f32>;
    [[location(6)]] rayorigin: vec3<f32>;
    [[location(7)]] half: vec4<f32>;


};

[[stage(vertex)]]
fn vertex([[builtin(vertex_index)]] vertex_index: u32) -> VertexOutput {
    var out: VertexOutput;

    let instance_index = vertex_index >> 3u;
    let cube = cubes.data[instance_index];

    // branchless mirroring
    let local_camera_pos = view.world_position - cube.center.xyz;
    let mirror_mask = u32(local_camera_pos.y < 0.0) << 2u | u32(local_camera_pos.z < 0.0) << 1u | u32(local_camera_pos.x < 0.0);
    let vx = vertex_index ^ mirror_mask;

    var xyz: vec3<i32> = vec3<i32>(
        i32(vx & 0x1u),
        i32((vx & 0x4u) >> 2u),
        i32((vx & 0x2u) >> 1u)
    );

    out.uvw = vec3<f32>(xyz);
    let relative_pos_unit = out.uvw * 2.0 - 1.0;
    let relative_pos = relative_pos_unit * cube.half_extents.xyz;
    out.half = cube.half_extents;
    // out.world_position = vec4<f32>(cube.center.xyz + relative_pos + view.world_position, 1.0) ;
    let vpos = vec4<f32>(cube.center.xyz + relative_pos, 1.0) ;
    out.cube_center = cube.center.xyz;
    out.raydir = vpos.xyz - view.world_position;

    out.world_position = vpos;
    out.world_normal = vec3<f32>(0.0, 0.0, 1.0);
    out.rayorigin = view.world_position;
    out.clip_position = view.view_proj * out.world_position;
    out.color = cube.color;
    return out;
}
//https://www.shadertoy.com/view/ldS3DW
struct FragmentInput {
    [[builtin(front_facing)]] is_front: bool;
    [[builtin(position)]] clip_position: vec4<f32>;

    [[location(0)]] world_position: vec4<f32>;
    [[location(1)]] world_normal: vec3<f32>;
    [[location(2)]] uvw: vec3<f32>;
    [[location(3)]] color: vec4<f32>;
    [[location(4)]] raydir: vec3<f32>;
    [[location(5)]] cube_center: vec3<f32>;
    [[location(6)]] rayorigin: vec3<f32>;
    [[location(7)]] half: vec4<f32>;



};
fn sphIntersect(ro: vec3<f32>, rd: vec3<f32>, sph: vec4<f32>) -> f32 {
    let oc = ro - sph.xyz;
    let  b = dot(oc, rd);
    let c = dot(oc, oc) - sph.w * sph.w;
    var h = b * b - c;
    if (h < 0.0) {
        return -1.0;
    }
    h = sqrt(h);
    return -b - h;
}
let ITERATIONS: i32 = 145;



// void main(void) {
//     // Screen space position
//     gl_Position = ViewProj * Model * vec4(Vertex_Position, 1.0);

//     // Voxel space position
//     fPos = Vertex_Position;

//     // World space position
//     vec3 pos = (Model * vec4(Vertex_Position, 1.0)).xyz;
    
//     fEye = pos - (inverse(ViewProj) * vec4(vec3(0), 1)).xyz;
//     // apply model rotation to ray
//     fEye = fEye * mat3(Model[0].xyz, Model[1].xyz, Model[2].xyz);

//     v_Position = vec4(Vertex_Position, 1.0);
// }

// [[stage(vertex)]]
// fn vertex(vertex: Vertex) -> VertexOutput {
//     // let world_position = view.view_proj * mesh.model * vec4<f32>(vertex.position, 1.0);
//     let world_position = view.view_proj * mesh.model * vec4<f32>(vertex.position, 1.0);

//     var out: VertexOutput;
//     out.clip_position =  world_position;
//     out.fpos = vertex.position;

//     let pos = (mesh.model * vec4<f32>(vertex.position, 1.0)).xyz;
    
//     let feye = pos - (view * vec4<f32>(.0, .0,.0, 1.)).xyz;
//     // let feye = pos - (view.view_proj * vec4<f32>(.0, .0,.0, 1.)).xyz;
//     // apply model rotation to ray
//     out.feye = feye * mat3x3<f32>(mesh.model[0].xyz, mesh.model[1].xyz, mesh.model[2].xyz);

//     return out;
// }


fn mandelbrot(uvw: vec3<f32>) -> vec4<f32> {
    let c: vec2<f32> = (vec3<f32>(uvw).xy + vec2<f32>(-0.6, -0.4)) * 4.0 ;
    var x: f32 = 0.0;
    var y: f32 = 0.0;
    var i: i32 = 0;

    for (; i < ITERATIONS; i = i + 1) {
        if (x * x + y * y > 4.) {
            break;
        }
        let xtemp: f32 = (x * x) - (y * y) + c.x;
        y = 2. * x * y + c.y;
        x = xtemp;
    }

    let frac: f32 = f32(i) / f32(ITERATIONS);
    let out = vec4<f32>(frac * 1., frac * 1., frac * 3., 0.5);
    return out;
}
fn sph_bad(uvw: vec3<f32>) -> vec2<f32> {

        {
        let  p = -1.0 + 2.0 * uvw.xy;
        let r = sqrt(dot(p, p));
        if (r < 1.0) {
            let f = (1.0 - sqrt(1.0 - r)) / (r);
            let x = p.x * f ;
            let y = p.y * f ;
            return vec2<f32>(x, y);
        }
        return vec2<f32>(0.0, 0.0);
    }
}



[[stage(fragment)]]
fn fragment(in: FragmentInput) -> [[location(0)]] vec4<f32> {
    // if ( > 0.7) {
    //     return vec4<f32>(0.0, 0.0, 1.0, 1.0);
    // }
    // let hit = sphIntersect(in.world_position.xyz, normalize(vec3<f32>(0.0,0.0,-1.0)), vec4<f32>(0.0, 0.0, 0.0, 10.0));
    let hit = sphIntersect(in.rayorigin, normalize(in.raydir), vec4<f32>(in.cube_center, 15.));


    let worldPos = normalize(in.raydir) * hit + in.rayorigin;

    // // let pct = distance(in.uvw, vec3<f32>(0.0, 0.0, 0.0));

    // // // return in.color;
    // return vec4<f32>(hit,hit, hit,  1.0);
    // var man = mandelbrot(in.uvw);
    var man = vec4<f32>(in.uvw, 1.0);
    if (hit < 0.0) {
        man = vec4<f32>(0.0, 0.0, 0.0, 0.0);
    };
    return man;

    // return vec4<f32>(sph_bad(in.uvw), 0.0, 1.0);
}

