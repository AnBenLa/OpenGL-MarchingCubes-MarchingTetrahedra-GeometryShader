#version 430
layout (points) in;
layout (triangle_strip, max_vertices = 40) out;

out fData
{
    vec3 position;
    vec3 normal;
    vec4 color;
}frag;

layout(binding=0) uniform sampler3D volume;
layout(binding=1) uniform isampler2D edgeTable;
layout(binding=2) uniform isampler2D triTable;
layout(binding=3) uniform isampler2D cellClass;
layout(binding=4) uniform isampler2D cellData;
layout(binding=5) uniform isampler2D vertexData;

uniform vec3 volume_dimensions;
uniform float iso_value;
uniform float voxel_size;
uniform int lod;
uniform int surface_shift;

uniform mat4 view;
uniform mat4 projection;
uniform mat4 model;
uniform vec3 camera_position;

vec4[8] corner = {
vec4(0, 0, 1, 0),
vec4(1, 0, 1, 0),
vec4(1, 0, 0, 0),
vec4(0, 0, 0, 0),

vec4(0, 1, 1, 0),
vec4(1, 1, 1, 0),
vec4(1, 1, 0, 0),
vec4(0, 1, 0, 0) };

// defines which corners make the edge determined by the first index
int edge_vertex_mapping[12][2] = {
{ 0, 1 },
{ 1, 2 },
{ 2, 3 },
{ 0, 3 },
{ 4, 5 },
{ 5, 6 },
{ 6, 7 },
{ 4, 7 },
{ 0, 4 },
{ 1, 5 },
{ 2, 6 },
{ 3, 7 }
};

int lod_function(vec3 voxel_position){
    if (length(vec3(0, 0, 0)/*camera_position*/ - (model*vec4(voxel_position, 1)).xyz) > 0.5)
        return 2;
    else
        return 1;
}
// has to be done since the texture coordinates are between 0,0,0 and 1,1,1
vec3 texture_position(vec4 position){
    return position.xyz/volume_dimensions;
}

float sample_volume(vec4 position){
    return texture(volume, texture_position(position)).a;
}

vec4 interpolate_vertex(float iso_value, vec4 a, vec4 b, float value_a, float value_b){
    return vec4((a + (iso_value - value_a)*(b - a)/(value_b - value_a)).xyz, 1);
}

vec4 interpolate_vertex_surface_shifting(float iso_value, vec4 a, vec4 b, float value_a, float value_b){
    vec4 c = (a+b)*0.5f;
    float value_c = sample_volume(c);

    if((value_a-iso_value)*(value_c-iso_value)<0){
        return vec4((a + (iso_value - value_a)*(c - a)/(value_c - value_a)).xyz, 1);
    }
    return vec4((b + (iso_value - value_b)*(c - b)/(value_c - value_b)).xyz, 1);
}

int check_for_occupancy(vec3 voxel_pos){
    int k = 1;
    int cube_index = 0;
    // sample the volume at each corner and store the result in the corner sample array
    // compute the index of the cube that will define which triangles will be generated
    // this works already
    for (int i = 0; i < 8; i++){
        // scale the voxels according to the voxel size
        float corner_sample = sample_volume(vec4(voxel_pos, 1) + corner[i]);
        if (corner_sample < iso_value) cube_index |= k;
        // do a bit shift in order to multiply with 2 faster
        k = k << 1;
    }
    return cube_index;
}

void marching_cubes(){
    float[8] corner_sample;
    mat4 mvp = projection * view * model;
    int cube_index = 0;
    int voxel_size_lod = 1;

    if (lod == 1){
        // voxel position normalized (always integer values after the division by voxel size)
        int x = int(gl_in[0].gl_Position.x / voxel_size);
        int y = int(gl_in[0].gl_Position.y / voxel_size);
        int z = int(gl_in[0].gl_Position.z / voxel_size);

        // base voxel position
        float x_base = (x - (x%2)) * voxel_size;
        float y_base = (y - (y%2)) * voxel_size;
        float z_base = (z - (z%2)) * voxel_size;

        // check for voxel size / lod
        voxel_size_lod = lod_function(vec3(x_base, y_base, z_base));

        // check if voxel is covered
        // if covered return;
        if (voxel_size_lod == 2 && (x % 2 == 1 || y % 2 == 1 || z % 2 == 1)){
            return;
        }
    }

    int k = 1;

    // sample the volume at each corner and store the result in the corner sample array
    // compute the index of the cube that will define which triangles will be generated
    // this works already
    for (int i = 0; i < 8; i++){
        // scale the voxels according to the voxel size
        corner_sample[i] = sample_volume(gl_in[0].gl_Position + voxel_size_lod * corner[i]);
        if (corner_sample[i] < iso_value) cube_index |= k;
        // do a bit shift in order to multiply with 2 faster
        k = k << 1;
    }

    // working!
    int cut_edges = texelFetch(edgeTable, ivec2(cube_index, 0), 0).r;

    vec4[12] vertices;
    k = 1;

    //in case the whole cube is outside the volume
    if (cut_edges == 0)
    return;

    // for all possible vertices that could be generated calculate the new interpolated vertex position if the vertex will be used
    for (int i = 0; i < 12; ++i){
        if ((cut_edges & k) == k){
            int a_index = edge_vertex_mapping[i][0];
            int b_index = edge_vertex_mapping[i][1];
            vec4 a = gl_in[0].gl_Position + voxel_size_lod * voxel_size * corner[a_index];
            vec4 b = gl_in[0].gl_Position + voxel_size_lod * voxel_size * corner[b_index];
            float value_a = corner_sample[a_index];
            float value_b = corner_sample[b_index];
            if(surface_shift == 0 || voxel_size_lod == 1){
                vertices[i] = interpolate_vertex(iso_value, a, b, value_a, value_b);
            } else {
                vertices[i] = interpolate_vertex_surface_shifting(iso_value, a, b, value_a, value_b);
            }
        }
        k = k << 1;
    }

    // chech which vertices will form a triangle by looking up in the triangle table
    // generate the triangles
    for (int i = 0; texelFetch(triTable, ivec2(i, cube_index), 0).r != -1; i += 3){
        vec4 vert_a = vertices[texelFetch(triTable, ivec2(i, cube_index), 0).r];
        vec4 vert_b = vertices[texelFetch(triTable, ivec2(i+1, cube_index), 0).r];
        vec4 vert_c = vertices[texelFetch(triTable, ivec2(i+2, cube_index), 0).r];

        vec3 a = vert_a.xyz - vert_b.xyz;
        vec3 b = vert_c.xyz - vert_b.xyz;
        frag.normal = abs(normalize(cross(a, b)));

        gl_Position = mvp * vert_a;
        frag.position = (model * vert_a).xyz;
        frag.color = model * vert_a;
        EmitVertex();

        gl_Position = mvp * vert_b;
        frag.position = (model * vert_b).xyz;
        frag.color = model * vert_b;
        EmitVertex();

        gl_Position = mvp * vert_c;
        frag.position = (model * vert_c).xyz;
        frag.color = model * vert_c;
        EmitVertex();
        EndPrimitive();
    }
}

void main() {
    // scale the voxels according to the voxel size
    for (int i = 0; i < 8; ++i)
    corner[i] = voxel_size * corner[i];

    marching_cubes();
}